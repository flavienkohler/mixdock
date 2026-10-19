// Long-running mode: keeps the state file current and carries out the skin's commands.
// Only one watcher runs at a time; `stop` asks it to exit. It also exits on its own when Rainmeter is gone.

using System;
using System.Diagnostics;
using System.Threading;

namespace AppMixer
{
    static class Watcher
    {
        const string MutexName = @"Local\AppMixerHelperWatch";
        const string StopEventName = @"Local\AppMixerHelperStop";
        const int IntervalMs = 1000;

        public static int Run(Config config, Options options)
        {
            using (var mutex = new Mutex(false, MutexName))
            {
                if (!Acquire(mutex)) return 0; // already watching
                Input.MakeDpiAware();
                using (var stop = new EventWaitHandle(false, EventResetMode.ManualReset, StopEventName))
                using (var audio = new AudioModel())
                using (var commands = new Commands(options.CommandsDir))
                {
                    string last = null;
                    Process[] rainmeter = Process.GetProcessesByName("Rainmeter");

                    // Writes the state if it changed and tells the skin to re-read it.
                    Action publish = () =>
                    {
                        string json = Program.Dump(audio, config, options);
                        if (json == last) return;
                        Program.WriteAtomically(options.StatePath, json);
                        last = json;
                        RainmeterLink.Refresh(options.Skin);
                    };

                    var handles = new WaitHandle[] { stop, commands.Signal };
                    do
                    {
                        commands.RunPending(audio, config, options, () => { config = Config.Load(options.ConfigPath, options.OrderPath); }, publish, (target, percent) => RainmeterLink.Preview(options.Skin, target, percent));
                        publish();
                    }
                    while (WaitHandle.WaitAny(handles, IntervalMs) != 0 && !AllExited(rainmeter));
                }
                mutex.ReleaseMutex();
            }
            return 0;
        }

        // A running watcher means nothing to do, unless it was just told to stop (skin reloaded): then wait for it to exit.
        static bool Acquire(Mutex mutex)
        {
            try
            {
                if (mutex.WaitOne(0)) return true;
                EventWaitHandle stop;
                if (!EventWaitHandle.TryOpenExisting(StopEventName, out stop)) return false;
                bool stopping;
                using (stop) { stopping = stop.WaitOne(0); }
                return stopping && mutex.WaitOne(3000);
            }
            catch (AbandonedMutexException) { return true; } // previous watcher crashed
        }

        public static bool Stop()
        {
            EventWaitHandle stop;
            if (!EventWaitHandle.TryOpenExisting(StopEventName, out stop)) return false;
            using (stop) { stop.Set(); }
            return true;
        }

        // The Rainmeter processes found at start; an empty list (started by hand) never ends the watcher.
        static bool AllExited(Process[] processes)
        {
            if (processes.Length == 0) return false;
            foreach (var p in processes) if (!p.HasExited) return false;
            return true;
        }
    }
}
