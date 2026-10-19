// Reads devices and per-app audio sessions into plain objects.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;

namespace AppMixer
{
    class DeviceInfo
    {
        public string Id;
        public string Name;
        public bool IsDefault;
    }

    class AppInfo
    {
        public string Process;   // process name without extension, used as the key
        public string Display;   // human readable name
        public string Path;      // executable path, may be null
        public float Volume;     // 0..1
        public bool Muted;
        public bool Idle;        // running but without any audio session, so there is no volume to control
        public bool Active;      // at least one session is playing right now
        public DateTime LastActive; // last time it was seen playing (UTC), MinValue if never
    }

    class AudioModel : IDisposable
    {
        readonly IMMDeviceEnumerator enumerator;

        // Process name, path and display name per process id, so a refresh does not hit the disk again.
        class ProcessInfo { public string Name, Path, Display; }
        readonly Dictionary<uint, ProcessInfo> processes = new Dictionary<uint, ProcessInfo>();
        readonly HashSet<uint> seen = new HashSet<uint>();

        // When each app was last seen playing. Only a long-running watcher remembers this across refreshes.
        readonly Dictionary<string, DateTime> lastActive = new Dictionary<string, DateTime>(StringComparer.OrdinalIgnoreCase);

        public AudioModel()
        {
            enumerator = (IMMDeviceEnumerator)new MMDeviceEnumeratorCom();
        }

        public void Dispose()
        {
            Marshal.ReleaseComObject(enumerator);
        }

        public List<DeviceInfo> ListRenderDevices()
        {
            var result = new List<DeviceInfo>();
            string defaultId = null;
            IMMDevice def;
            if (enumerator.GetDefaultAudioEndpoint(Const.ERender, Const.EMultimedia, out def) == 0)
            {
                def.GetId(out defaultId);
                Marshal.ReleaseComObject(def);
            }

            IMMDeviceCollection collection;
            if (enumerator.EnumAudioEndpoints(Const.ERender, Const.DeviceStateActive, out collection) != 0)
                return result;
            uint count;
            collection.GetCount(out count);
            for (uint i = 0; i < count; i++)
            {
                IMMDevice device;
                if (collection.Item(i, out device) != 0) continue;
                string id;
                device.GetId(out id);
                result.Add(new DeviceInfo { Id = id, Name = FriendlyName(device), IsDefault = id == defaultId });
                Marshal.ReleaseComObject(device);
            }
            Marshal.ReleaseComObject(collection);
            return result;
        }

        static string FriendlyName(IMMDevice device)
        {
            IPropertyStore store;
            if (device.OpenPropertyStore(Const.StgmRead, out store) != 0) return "Unknown device";
            // PKEY_Device_FriendlyName
            var key = new PropertyKey { fmtid = new Guid("A45C254E-DF1C-4EFD-8020-67D146A850E0"), pid = 14 };
            PropVariant value;
            string name = "Unknown device";
            if (store.GetValue(ref key, out value) == 0)
            {
                if (value.vt == 31 && value.data1 != IntPtr.Zero) // VT_LPWSTR
                    name = Marshal.PtrToStringUni(value.data1);
                Native.PropVariantClear(ref value);
            }
            Marshal.ReleaseComObject(store);
            return name;
        }

        // Master volume and mute of the default playback device. Returns false when there is none.
        public bool ReadDefaultVolume(out float volume, out bool muted)
        {
            volume = 0; muted = false;
            IMMDevice device;
            if (enumerator.GetDefaultAudioEndpoint(Const.ERender, Const.EMultimedia, out device) != 0) return false;
            try
            {
                var iid = Iid.AudioEndpointVolume;
                object o;
                if (device.Activate(ref iid, Const.ClsctxAll, IntPtr.Zero, out o) != 0) return false;
                var endpoint = (IAudioEndpointVolume)o;
                endpoint.GetMasterVolumeLevelScalar(out volume);
                endpoint.GetMute(out muted);
                Marshal.ReleaseComObject(endpoint);
                return true;
            }
            finally { Marshal.ReleaseComObject(device); }
        }

        // Audio sessions of every active playback device, merged by process name.
        // An app that plays on a device other than the default is still listed.
        public List<AppInfo> ReadApps()
        {
            var apps = new Dictionary<string, AppInfo>(StringComparer.OrdinalIgnoreCase);
            var mutedAll = new Dictionary<string, bool>(StringComparer.OrdinalIgnoreCase);
            seen.Clear();

            ForEachSession(session => ReadSession(session, apps, mutedAll));

            processes.Keys.Where(pid => !seen.Contains(pid)).ToList().ForEach(pid => processes.Remove(pid));

            DateTime now = DateTime.UtcNow;
            var list = new List<AppInfo>(apps.Values);
            foreach (var app in list)
            {
                app.Muted = mutedAll[app.Process];
                if (app.Active) lastActive[app.Process] = now;
                DateTime last;
                app.LastActive = lastActive.TryGetValue(app.Process, out last) ? last : DateTime.MinValue;
            }
            list.Sort((a, b) => string.Compare(a.Display, b.Display, StringComparison.CurrentCultureIgnoreCase));
            return list;
        }

        // Calls visit for every audio session of every active playback device.
        void ForEachSession(Action<IAudioSessionControl2> visit)
        {
            IMMDeviceCollection devices;
            if (enumerator.EnumAudioEndpoints(Const.ERender, Const.DeviceStateActive, out devices) != 0) return;
            uint deviceCount;
            devices.GetCount(out deviceCount);
            for (uint d = 0; d < deviceCount; d++)
            {
                IMMDevice device;
                if (devices.Item(d, out device) != 0) continue;
                try
                {
                    var iid = Iid.AudioSessionManager2;
                    object o;
                    if (device.Activate(ref iid, Const.ClsctxAll, IntPtr.Zero, out o) != 0) continue;
                    var manager = (IAudioSessionManager2)o;
                    IAudioSessionEnumerator sessions;
                    manager.GetSessionEnumerator(out sessions);
                    int count;
                    sessions.GetCount(out count);
                    for (int i = 0; i < count; i++)
                    {
                        IAudioSessionControl2 session;
                        if (sessions.GetSession(i, out session) != 0) continue;
                        try { visit(session); }
                        finally { Marshal.ReleaseComObject(session); }
                    }
                    Marshal.ReleaseComObject(sessions);
                    Marshal.ReleaseComObject(manager);
                }
                finally { Marshal.ReleaseComObject(device); }
            }
            Marshal.ReleaseComObject(devices);
        }

        // The process behind a session, or null for expired sessions, system sounds and unknown processes.
        ProcessInfo SessionProcess(IAudioSessionControl2 session, out int state, out uint pid)
        {
            pid = 0;
            session.GetState(out state);
            if (state == Const.SessionStateExpired) return null;
            if (session.IsSystemSoundsSession() == 0) return null;
            // A session shared by several processes returns the success code AUDCLNT_S_NO_SINGLE_PROCESS
            // with the id of the process that created it, so only a negative result is a failure.
            if (session.GetProcessId(out pid) < 0 || pid == 0) return null;
            return Lookup(pid);
        }

        void ReadSession(IAudioSessionControl2 session, Dictionary<string, AppInfo> apps, Dictionary<string, bool> mutedAll)
        {
            int state; uint pid;
            ProcessInfo info = SessionProcess(session, out state, out pid);
            if (info == null) return;
            seen.Add(pid);
            string process = info.Name, path = info.Path;
            var volume = session as ISimpleAudioVolume;
            if (volume == null) return;
            float level; bool muted;
            volume.GetMasterVolume(out level);
            volume.GetMute(out muted);

            bool active = state == Const.SessionStateActive;
            AppInfo app;
            if (!apps.TryGetValue(process, out app))
            {
                app = new AppInfo { Process = process, Path = path, Volume = level, Display = info.Display, Active = active };
                apps[process] = app;
                mutedAll[process] = muted;
            }
            else
            {
                if (path != null && app.Path == null) app.Path = path;
                app.Volume = Math.Max(app.Volume, level);
                app.Active = app.Active || active;
                mutedAll[process] = mutedAll[process] && muted;
            }
        }

        // ---- Writing: a change applies to every session of the app, on every playback device. ----

        void ForAppSessions(string process, Action<ISimpleAudioVolume> apply)
        {
            ForEachSession(session =>
            {
                int state; uint pid;
                ProcessInfo info = SessionProcess(session, out state, out pid);
                if (info == null || !string.Equals(info.Name, process, StringComparison.OrdinalIgnoreCase)) return;
                var volume = session as ISimpleAudioVolume;
                if (volume != null) apply(volume);
            });
        }

        public void SetAppVolume(string process, float level)
        {
            level = Clamp01(level);
            Guid context = Guid.Empty;
            ForAppSessions(process, v => v.SetMasterVolume(level, ref context));
        }

        // mode: "on", "off" or "toggle" (mutes all sessions unless they are all muted already).
        public void SetAppMute(string process, string mode)
        {
            bool mute = mode == "on";
            if (mode == "toggle")
            {
                bool allMuted = true, any = false;
                ForAppSessions(process, v => { bool m; v.GetMute(out m); allMuted &= m; any = true; });
                mute = any && !allMuted;
            }
            Guid context = Guid.Empty;
            ForAppSessions(process, v => v.SetMute(mute, ref context));
        }

        public void SetMasterVolume(float level)
        {
            level = Clamp01(level);
            Guid context = Guid.Empty;
            WithDefaultEndpoint(e => e.SetMasterVolumeLevelScalar(level, ref context));
        }

        public void ToggleMasterMute()
        {
            Guid context = Guid.Empty;
            WithDefaultEndpoint(e => { bool m; e.GetMute(out m); e.SetMute(!m, ref context); });
        }

        void WithDefaultEndpoint(Action<IAudioEndpointVolume> action)
        {
            IMMDevice device;
            if (enumerator.GetDefaultAudioEndpoint(Const.ERender, Const.EMultimedia, out device) != 0) return;
            try
            {
                var iid = Iid.AudioEndpointVolume;
                object o;
                if (device.Activate(ref iid, Const.ClsctxAll, IntPtr.Zero, out o) != 0) return;
                var endpoint = (IAudioEndpointVolume)o;
                try { action(endpoint); }
                finally { Marshal.ReleaseComObject(endpoint); }
            }
            finally { Marshal.ReleaseComObject(device); }
        }

        // Makes the playback device matching an alias from the config the default one. Returns false if none is active.
        public bool SetOutput(Config config, string alias)
        {
            DeviceEntry entry = config.Devices.Find(d => string.Equals(d.Alias, alias, StringComparison.OrdinalIgnoreCase));
            if (entry == null) return false;
            DeviceInfo device = ListRenderDevices().Find(d => d.Name.IndexOf(entry.Match, StringComparison.OrdinalIgnoreCase) >= 0);
            if (device == null) return false;
            if (!device.IsDefault) DefaultDevice.Set(device.Id);
            return true;
        }

        static float Clamp01(float v) { return v < 0 ? 0 : (v > 1 ? 1 : v); }

        // A running process that has no audio session (yet). Used to list pinned apps while they are silent.
        public AppInfo FindIdle(string process)
        {
            Process[] found = Process.GetProcessesByName(process);
            try
            {
                if (found.Length == 0) return null;
                string path = ProcessPath((uint)found[0].Id);
                return new AppInfo { Process = found[0].ProcessName, Path = path, Display = DisplayName(found[0].ProcessName, path) };
            }
            finally { foreach (var p in found) p.Dispose(); }
        }

        ProcessInfo Lookup(uint pid)
        {
            ProcessInfo info;
            if (processes.TryGetValue(pid, out info)) return info;
            string name;
            try { using (var p = Process.GetProcessById((int)pid)) name = p.ProcessName; }
            catch (Exception) { return null; }
            string path = ProcessPath(pid);
            info = new ProcessInfo { Name = name, Path = path, Display = DisplayName(name, path) };
            processes[pid] = info;
            return info;
        }

        static string ProcessPath(uint pid)
        {
            IntPtr handle = Native.OpenProcess(0x1000, false, pid); // PROCESS_QUERY_LIMITED_INFORMATION
            if (handle == IntPtr.Zero) return null;
            try
            {
                var sb = new StringBuilder(1024);
                uint size = (uint)sb.Capacity;
                return Native.QueryFullProcessImageName(handle, 0, sb, ref size) ? sb.ToString() : null;
            }
            finally { Native.CloseHandle(handle); }
        }

        static string DisplayName(string process, string path)
        {
            if (path != null)
            {
                try
                {
                    var info = FileVersionInfo.GetVersionInfo(path);
                    if (!string.IsNullOrWhiteSpace(info.FileDescription)) return info.FileDescription.Trim();
                    if (!string.IsNullOrWhiteSpace(info.ProductName)) return info.ProductName.Trim();
                }
                catch (Exception) { }
            }
            return process;
        }
    }
}
