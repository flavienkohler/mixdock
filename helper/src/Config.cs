// User configuration: which output devices get a button, and which apps to hide.
//
// {
//   "devices": [ { "alias": "headset", "label": "Headset", "match": "part of the device name" } ],
//   "pinned": [ "process name without .exe" ],   always listed while the app runs, shown first
//   "exclude": [ "process name without .exe" ],  never listed
//   "graceSeconds": 60                           how long an app stays listed after it stops playing
// }

using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Web.Script.Serialization;

namespace AppMixer
{
    class DeviceEntry
    {
        public string Alias, Label, Match;
    }

    class Config
    {
        public List<DeviceEntry> Devices = new List<DeviceEntry>();
        readonly HashSet<string> exclude = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        readonly HashSet<string> pinned = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        // How long an app stays listed after it stopped playing (unless it is pinned).
        public int GraceSeconds = 60;

        public bool IsExcluded(string process) { return exclude.Contains(process); }
        public bool IsPinned(string process) { return pinned.Contains(process); }
        public IEnumerable<string> Pinned { get { return pinned; } }

        public static Config Load(string path)
        {
            var config = new Config();
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
                        Label = d.ContainsKey("label") ? Convert.ToString(d["label"]) : alias
                    });
                }
            }
            object excluded;
            if (root.TryGetValue("exclude", out excluded) && excluded is IEnumerable)
                foreach (var item in (IEnumerable)excluded) config.exclude.Add(Convert.ToString(item));
            object pinnedApps;
            if (root.TryGetValue("pinned", out pinnedApps) && pinnedApps is IEnumerable)
                foreach (var item in (IEnumerable)pinnedApps) config.pinned.Add(Convert.ToString(item));
            object grace;
            if (root.TryGetValue("graceSeconds", out grace)) config.GraceSeconds = Math.Max(0, Convert.ToInt32(grace));
            return config;
        }
    }
}
