// Commands from the skin. Each command is a small tab-separated file dropped into the Commands folder:
//
//   volume   <process> <0-100>
//   mute     <process> <toggle|on|off>
//   master   <0-100>
//   master-mute
//   output   <alias>
//   drag     <process|@master> <start 0-100> <slider width in design pixels>
//
// The watcher picks files up as soon as they appear, so a click costs no process start.
// `drag` sets the start value, then follows the cursor until the left button is released.

using System;
using System.Collections.Generic;
using System.IO;
using System.Threading;

namespace AppMixer
{
    class Commands : IDisposable
    {
        public const string Master = "@master";

        readonly string dir;
        readonly FileSystemWatcher watcher;
        public readonly AutoResetEvent Signal = new AutoResetEvent(false);

        public Commands(string dir)
        {
            this.dir = dir;
            Directory.CreateDirectory(dir);
            foreach (string stale in Directory.GetFiles(dir)) TryDelete(stale);
            watcher = new FileSystemWatcher(dir, "*.cmd");
            watcher.Created += (s, e) => Signal.Set();
            watcher.Renamed += (s, e) => Signal.Set(); // the skin writes a temporary file, then renames it
            watcher.EnableRaisingEvents = true;
        }

        public void Dispose()
        {
            watcher.Dispose();
            Signal.Dispose();
        }

        // Runs every pending command, oldest first. `publish` writes the state and tells the skin.
        public void RunPending(AudioModel audio, Config config, Action publish, Action<string, int> preview)
        {
            string[] files = Directory.GetFiles(dir, "*.cmd");
            Array.Sort(files, StringComparer.Ordinal);
            foreach (string file in files)
            {
                string text = Read(file);
                TryDelete(file);
                if (string.IsNullOrWhiteSpace(text)) continue;
                try { Execute(audio, config, text.Trim().Split('\t'), publish, preview); }
                catch (Exception e) { Console.Error.WriteLine("command failed: " + e.Message); }
            }
        }

        static void Execute(AudioModel audio, Config config, string[] c, Action publish, Action<string, int> preview)
        {
            switch (c[0])
            {
                case "volume":
                    audio.SetAppVolume(c[1], Percent(c[2]));
                    break;
                case "mute":
                    audio.SetAppMute(c[1], c.Length > 2 ? c[2] : "toggle");
                    break;
                case "master":
                    audio.SetMasterVolume(Percent(c[1]));
                    break;
                case "master-mute":
                    audio.ToggleMasterMute();
                    break;
                case "output":
                    audio.SetOutput(config, c[1]);
                    break;
                case "drag":
                    Drag(audio, c[1], (int)Math.Round(double.Parse(c[2], System.Globalization.CultureInfo.InvariantCulture)),
                         double.Parse(c[3], System.Globalization.CultureInfo.InvariantCulture), publish, preview);
                    return;
            }
            publish();
        }

        // Relative drag: the start value is where the press landed, then the cursor's horizontal movement
        // maps to the slider's width on the screen the cursor is on. While dragging, only a small preview goes to
        // the skin; the full state is written once at the end.
        static void Drag(AudioModel audio, string target, int start, double designWidth, Action publish, Action<string, int> preview)
        {
            int x0 = Input.CursorX();
            double widthPx = Math.Max(1, designWidth * Input.CursorScale());
            int last = Clamp(start);
            Apply(audio, target, last);
            preview(target, last);
            while (Input.LeftButtonDown())
            {
                int value = Clamp((int)Math.Round(start + (Input.CursorX() - x0) * 100.0 / widthPx));
                if (value != last)
                {
                    last = value;
                    Apply(audio, target, value);
                    preview(target, value); // cheap: moves just this slider in the skin
                }
                Thread.Sleep(10);
            }
            publish(); // one full refresh when the button is released
        }

        static void Apply(AudioModel audio, string target, int percent)
        {
            if (target == Master) audio.SetMasterVolume(percent / 100f);
            else audio.SetAppVolume(target, percent / 100f);
        }

        static float Percent(string text)
        {
            return Clamp((int)Math.Round(double.Parse(text, System.Globalization.CultureInfo.InvariantCulture))) / 100f;
        }

        static int Clamp(int percent) { return percent < 0 ? 0 : (percent > 100 ? 100 : percent); }

        static string Read(string file)
        {
            for (int attempt = 0; attempt < 5; attempt++)
            {
                try { return File.ReadAllText(file); }
                catch (IOException) { Thread.Sleep(10); }
            }
            return null;
        }

        static void TryDelete(string file)
        {
            try { File.Delete(file); } catch (IOException) { }
        }
    }
}
