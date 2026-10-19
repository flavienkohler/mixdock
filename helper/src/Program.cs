// Mixdock helper: reads Windows audio state and writes it to a JSON file for the Rainmeter skin.
//
// Usage: MixdockHelper dump [--stdout] [--state <file>] [--icons <dir>] [--config <file>]

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Web.Script.Serialization;

namespace Mixdock
{
    static class Program
    {
        static int Main(string[] args)
        {
            string command = args.Length > 0 ? args[0] : "";
            if (command != "dump" && command != "watch" && command != "stop" && command != "set-output")
            {
                Console.Error.WriteLine("usage: MixdockHelper dump|watch|stop|set-output <alias> [--stdout] [--state <file>] [--icons <dir>] [--config <file>]");
                return 2;
            }
            try
            {
                var options = Options.Parse(args);
                if (command == "stop") return Watcher.Stop() ? 0 : 1;
                Config.EnsureExists(options.ConfigPath);
                var config = Config.Load(options.ConfigPath, options.OrderPath);
                if (command == "watch") return Watcher.Run(config, options);
                if (command == "set-output")
                {
                    using (var audio = new AudioModel())
                        return args.Length > 1 && audio.SetOutput(config, args[1]) ? 0 : 1;
                }
                string json = Dump(config, options);
                if (options.Stdout) Console.Out.WriteLine(json);
                else WriteAtomically(options.StatePath, json);
                return 0;
            }
            catch (Exception e)
            {
                Console.Error.WriteLine(e.Message);
                return 1;
            }
        }

        public static string Dump(Config config, Options options)
        {
            using (var audio = new AudioModel())
            {
                return Dump(audio, config, options);
            }
        }

        public static string Dump(AudioModel audio, Config config, Options options)
        {
            List<string> shownPinned, shownOthers;
            return Build(audio, config, options, out shownPinned, out shownOthers);
        }

        // Builds the state JSON. `shownPinned` and `shownOthers` receive the listed apps of each group, in display order.
        public static string Build(AudioModel audio, Config config, Options options,
                                   out List<string> shownPinned, out List<string> shownOthers)
        {
            var devices = audio.ListRenderDevices();
            var apps = audio.ReadApps();
            float masterVolume; bool masterMuted;
            bool hasOutput = audio.ReadDefaultVolume(out masterVolume, out masterMuted);

            string defaultName = null, defaultAlias = null;
            var deviceList = new List<object>();
            foreach (var entry in config.Devices)
            {
                DeviceInfo match = devices.Find(d => d.Name.IndexOf(entry.Match, StringComparison.OrdinalIgnoreCase) >= 0);
                deviceList.Add(new Dictionary<string, object> {
                    { "alias", entry.Alias },
                    { "name", entry.Label },
                    { "icon", entry.Icon },
                    { "available", match != null },
                    { "active", match != null && match.IsDefault }
                });
                if (match != null && match.IsDefault) defaultAlias = entry.Alias;
            }
            foreach (var d in devices) if (d.IsDefault) defaultName = d.Name;

            // Listed: playing now, played within the grace period, or pinned. Pinned apps come first.
            DateTime now = DateTime.UtcNow;
            var visible = apps.FindAll(a => options.All || !config.IsExcluded(a.Process) &&
                (a.Active || config.IsPinned(a.Process) || (now - a.LastActive).TotalSeconds < config.GraceSeconds));

            // A pinned app that is running but has no audio session yet is listed as idle (no volume to control).
            foreach (string name in config.PinnedOrder.ToList())
            {
                if (visible.Exists(a => string.Equals(a.Process, name, StringComparison.OrdinalIgnoreCase))) continue;
                AppInfo idle = audio.FindIdle(name);
                if (idle != null && !config.IsExcluded(idle.Process)) { idle.Idle = true; visible.Add(idle); }
            }
            // Pinned apps first. Inside each group: the order the user chose, then alphabetical.
            visible = visible.OrderBy(a => config.IsPinned(a.Process) ? 0 : 1)
                             .ThenBy(a => config.OrderIndex(a.Process))
                             .ThenBy(a => a.Display, StringComparer.CurrentCultureIgnoreCase).ToList();
            shownPinned = visible.Where(a => config.IsPinned(a.Process)).Select(a => a.Process).ToList();
            shownOthers = visible.Where(a => !config.IsPinned(a.Process)).Select(a => a.Process).ToList();

            var appList = new List<object>();
            foreach (var app in visible)
            {
                appList.Add(new Dictionary<string, object> {
                    { "process", app.Process },
                    { "name", app.Display },
                    { "volume", (int)Math.Round(app.Volume * 100) },
                    { "muted", app.Muted },
                    { "active", app.Active },
                    { "pinned", config.IsPinned(app.Process) },
                    { "idle", app.Idle },
                    { "icon", Icons.Cache(app.Process, app.Path, options.IconsDir) }
                });
            }

            var state = new Dictionary<string, object> {
                { "output", new Dictionary<string, object> {
                    { "alias", defaultAlias },
                    { "name", defaultName },
                    { "volume", hasOutput ? (int)Math.Round(masterVolume * 100) : 0 },
                    { "muted", masterMuted }
                } },
                { "devices", deviceList },
                { "apps", appList }
            };
            return new JavaScriptSerializer().Serialize(state);
        }

        // Write to a temporary file and rename, so the skin never reads a half-written file.
        public static void WriteAtomically(string path, string content)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            string temp = path + ".tmp";
            File.WriteAllText(temp, content, new UTF8Encoding(false));
            if (File.Exists(path)) File.Replace(temp, path, null);
            else File.Move(temp, path);
        }
    }

    public class Options
    {
        public bool Stdout, All; // All: list every session, ignoring pinned/grace/exclude (for debugging)
        public string StatePath, IconsDir, ConfigPath, CommandsDir, OrderPath;
        public string Skin = "Mixdock"; // name of the Rainmeter skin to notify

        public static Options Parse(string[] args)
        {
            string exeDir = AppDomain.CurrentDomain.BaseDirectory;
            var o = new Options {
                StatePath = Path.GetFullPath(Path.Combine(exeDir, @"..\@Resources\State\state.json")),
                IconsDir = Path.GetFullPath(Path.Combine(exeDir, @"..\@Resources\Icons")),
                CommandsDir = Path.GetFullPath(Path.Combine(exeDir, @"..\@Resources\Commands")),
                OrderPath = Path.GetFullPath(Path.Combine(exeDir, @"..\@Resources\State\order.txt")),
                ConfigPath = Path.Combine(exeDir, "config.json")
            };
            for (int i = 1; i < args.Length; i++)
            {
                if (args[i] == "--stdout") o.Stdout = true;
                else if (args[i] == "--all") o.All = true;
                else if (args[i] == "--skin" && i + 1 < args.Length) o.Skin = args[++i];
                else if (args[i] == "--state" && i + 1 < args.Length) o.StatePath = Path.GetFullPath(args[++i]);
                else if (args[i] == "--icons" && i + 1 < args.Length) o.IconsDir = Path.GetFullPath(args[++i]);
                else if (args[i] == "--config" && i + 1 < args.Length) o.ConfigPath = Path.GetFullPath(args[++i]);
            }
            return o;
        }
    }
}
