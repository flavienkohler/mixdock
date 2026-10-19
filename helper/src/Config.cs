// User configuration: which output devices get a button, and which apps to hide.
//
// {
//   "devices": [ { "alias": "headset", "label": "Headset", "match": "part of the device name", "icon": "headset" } ],
//                  icon is optional (headset, speakers, monitor, jack, gamepad): the compact layout shows it, or the output's number
//   "pinned": [ "process name without .exe" ],   always listed while the app runs, shown first
//   "exclude": [ "process name without .exe" ],  never listed
//   "graceSeconds": 60                           how long an app stays listed after it stops playing
// }

using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Web.Script.Serialization;

namespace AppMixer
{
    class DeviceEntry
    {
        public string Alias, Label, Match, Icon; // Icon: optional, shown instead of the label in the compact layout
    }

    class Config
    {
        public List<DeviceEntry> Devices = new List<DeviceEntry>();
        readonly HashSet<string> exclude = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        // Pinned apps in the order of the "pinned" list of the config file.
        public readonly NameOrder PinnedOrder = new NameOrder();

        // Display order of the other apps, remembered in a small state file (these apps come and go, so it does
        // not belong in the config). Apps that are not in it are listed alphabetically after those that are.
        public readonly NameOrder OtherOrder = new NameOrder();

        // How long an app stays listed after it stopped playing (unless it is pinned).
        public int GraceSeconds = 60;

        public bool IsExcluded(string process) { return exclude.Contains(process); }
        public bool IsPinned(string process) { return PinnedOrder.Contains(process); }

        // Position inside the app's own group (pinned or other), int.MaxValue if it has no chosen position.
        public int OrderIndex(string process)
        {
            return IsPinned(process) ? PinnedOrder.IndexOf(process) : OtherOrder.IndexOf(process);
        }

        public void LoadOtherOrder(string path)
        {
            OtherOrder.Clear();
            if (!File.Exists(path)) return;
            foreach (string line in File.ReadAllLines(path))
                if (line.Trim().Length > 0) OtherOrder.Add(line.Trim());
        }

        public void SaveOtherOrder(string path)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            string temp = path + ".tmp";
            File.WriteAllLines(temp, OtherOrder.Items, new UTF8Encoding(false));
            if (File.Exists(path)) File.Replace(temp, path, null); else File.Move(temp, path);
        }
        // Adds the app to the "pinned" list of the config file, or removes it if it is already there.
        // Returns true when the app is now pinned.
        public static bool TogglePin(string path, string process)
        {
            List<string> list = ReadPinnedList(File.Exists(path) ? File.ReadAllText(path) : "");
            bool pinned = !list.Exists(p => string.Equals(p, process, StringComparison.OrdinalIgnoreCase));
            if (pinned) list.Add(process);
            else list.RemoveAll(p => string.Equals(p, process, StringComparison.OrdinalIgnoreCase));
            WritePinnedList(path, list);
            return pinned;
        }

        static List<string> ReadPinnedList(string text)
        {
            var list = new List<string>();
            var array = Regex.Match(text, "\"pinned\"\\s*:\\s*\\[(?<items>[^\\]]*)\\]");
            if (array.Success)
                foreach (Match item in Regex.Matches(array.Groups["items"].Value, "\"((?:[^\"\\\\]|\\\\.)*)\""))
                    list.Add(Regex.Unescape(item.Groups[1].Value));
            return list;
        }

        // Rewrites only the "pinned" list of the config file, so the rest keeps the user's formatting.
        public static void WritePinnedList(string path, List<string> list)
        {
            string text = File.Exists(path) ? File.ReadAllText(path) : "{\n}\n";
            string inline = "\"pinned\": [" + (list.Count == 0 ? "" : " " + string.Join(", ", list.ConvertAll(Quote)) + " ") + "]";
            var array = Regex.Match(text, "\"pinned\"\\s*:\\s*\\[(?<items>[^\\]]*)\\]");
            if (array.Success) text = text.Substring(0, array.Index) + inline + text.Substring(array.Index + array.Length);
            else text = InsertFirst(text, inline);

            string temp = path + ".tmp";
            File.WriteAllText(temp, text, new UTF8Encoding(false));
            if (File.Exists(path)) File.Replace(temp, path, null); else File.Move(temp, path);
        }

        static string InsertFirst(string text, string inline)
        {
            int brace = text.IndexOf('{');
            string rest = text.Substring(brace + 1);
            string comma = rest.TrimStart().StartsWith("}") ? "" : ","; // no trailing comma in an empty object
            return text.Substring(0, brace + 1) + "\n  " + inline + comma + rest;
        }

        static string Quote(string s) { return "\"" + s.Replace("\\", "\\\\").Replace("\"", "\\\"") + "\""; }

        public static Config Load(string path, string otherOrderPath = null)
        {
            var config = new Config();
            if (otherOrderPath != null) config.LoadOtherOrder(otherOrderPath);
            if (!File.Exists(path)) return config;

            var root = new JavaScriptSerializer().DeserializeObject(File.ReadAllText(path)) as Dictionary<string, object>;
            if (root == null) throw new InvalidDataException("config: expected a JSON object in " + path);

            object devices;
            if (root.TryGetValue("devices", out devices) && devices is IEnumerable)
            {
                foreach (var item in (IEnumerable)devices)
                {
                    var d = item as Dictionary<string, object>;
                    if (d == null || !d.ContainsKey("alias") || !d.ContainsKey("match")) continue;
                    string alias = Convert.ToString(d["alias"]);
                    config.Devices.Add(new DeviceEntry {
                        Alias = alias,
                        Match = Convert.ToString(d["match"]),
                        Label = d.ContainsKey("label") ? Convert.ToString(d["label"]) : alias,
                        Icon = d.ContainsKey("icon") ? Convert.ToString(d["icon"]) : null
                    });
                }
            }
            object excluded;
            if (root.TryGetValue("exclude", out excluded) && excluded is IEnumerable)
                foreach (var item in (IEnumerable)excluded) config.exclude.Add(Convert.ToString(item));
            object pinnedApps;
            if (root.TryGetValue("pinned", out pinnedApps) && pinnedApps is IEnumerable)
                foreach (var item in (IEnumerable)pinnedApps)
                    config.PinnedOrder.Add(Convert.ToString(item));
            object grace;
            if (root.TryGetValue("graceSeconds", out grace)) config.GraceSeconds = Math.Max(0, Convert.ToInt32(grace));
            return config;
        }
    }
}
