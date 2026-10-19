// An ordered list of app (process) names, matched without regard to case. Used for the display order of the
// pinned apps and of the other apps.

using System;
using System.Collections.Generic;

namespace Mixdock
{
    class NameOrder
    {
        readonly List<string> items = new List<string>();

        public IEnumerable<string> Items { get { return items; } }
        public List<string> ToList() { return new List<string>(items); }

        public bool Contains(string name) { return IndexOf(name) != int.MaxValue; }

        // Position of the name (0 = first), or int.MaxValue when it is not in the list.
        public int IndexOf(string name)
        {
            int i = items.FindIndex(n => Same(n, name));
            return i < 0 ? int.MaxValue : i;
        }

        public void Clear() { items.Clear(); }

        public void Add(string name)
        {
            if (!Contains(name)) items.Add(name);
        }

        // Appends the names that are missing, in the given order.
        public void EnsureContains(IEnumerable<string> names)
        {
            foreach (string name in names) Add(name);
        }

        // `shown` are the names currently listed, `newOrder` is the same set in the wanted order. They take over the
        // slots the shown names occupy, so names that are not listed right now keep their place. All shown names
        // must be in the list (see EnsureContains).
        public void ReorderShown(List<string> shown, List<string> newOrder)
        {
            var slots = new List<int>();
            for (int i = 0; i < items.Count; i++)
                if (shown.Exists(s => Same(s, items[i]))) slots.Add(i);
            for (int k = 0; k < slots.Count && k < newOrder.Count; k++) items[slots[k]] = newOrder[k];
        }

        static bool Same(string a, string b) { return string.Equals(a, b, StringComparison.OrdinalIgnoreCase); }
    }
}
