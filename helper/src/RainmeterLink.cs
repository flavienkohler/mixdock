// Tells the running skin that the state changed, by sending a bang to Rainmeter's control window.
// This is the same message Rainmeter.exe uses to forward command line bangs, without starting a process.

using System;
using System.Runtime.InteropServices;

namespace Mixdock
{
    static class RainmeterLink
    {
        [StructLayout(LayoutKind.Sequential)]
        struct CopyData { public IntPtr dwData; public int cbData; public IntPtr lpData; }

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        static extern IntPtr FindWindow(string className, string title);

        [DllImport("user32.dll")]
        static extern IntPtr SendMessage(IntPtr window, uint message, IntPtr wParam, ref CopyData data);

        const uint WmCopyData = 0x004A;

        static IntPtr window;

        public static bool Send(string bang)
        {
            if (window == IntPtr.Zero)
                window = FindWindow("DummyRainWClass", "Rainmeter control window");
            if (window == IntPtr.Zero) return false;

            var data = new CopyData { dwData = (IntPtr)1, cbData = (bang.Length + 1) * 2 };
            data.lpData = Marshal.StringToHGlobalUni(bang);
            try { SendMessage(window, WmCopyData, IntPtr.Zero, ref data); }
            finally { Marshal.FreeHGlobal(data.lpData); }
            return true;
        }

        // Moves one slider in the skin right away while it is being dragged, without a full state refresh.
        public static void Preview(string skin, string target, int percent)
        {
            if (target.IndexOfAny(new[] { '\"', '\'', '[', ']' }) >= 0) return;
            Send("[!CommandMeasure \"Mixer\" \"Preview('" + target + "'," + percent + ")\" \"" + skin + "\"]");
        }

        // Asks the skin's script to re-read the state file now.
        public static void Refresh(string skin)
        {
            if (!Send("[!CommandMeasure \"Mixer\" \"Refresh()\" \"" + skin + "\"]")) window = IntPtr.Zero;
        }
    }
}
