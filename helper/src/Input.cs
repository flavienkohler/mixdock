// Mouse state and display scaling, used to follow a slider drag that Rainmeter itself cannot report.

using System;
using System.Runtime.InteropServices;

namespace AppMixer
{
    static class Input
    {
        [StructLayout(LayoutKind.Sequential)]
        struct Point { public int X, Y; }

        [DllImport("user32.dll")] static extern bool GetCursorPos(out Point p);
        [DllImport("user32.dll")] static extern short GetAsyncKeyState(int key);
        [DllImport("user32.dll")] static extern IntPtr MonitorFromPoint(Point p, uint flags);
        [DllImport("user32.dll")] static extern bool SetProcessDpiAwarenessContext(IntPtr context);
        [DllImport("shcore.dll")] static extern int GetDpiForMonitor(IntPtr monitor, int type, out uint dpiX, out uint dpiY);

        const int VkLButton = 0x01;
        const uint MonitorDefaultToNearest = 2;

        // Per-monitor DPI awareness makes cursor positions real pixels on every screen.
        public static void MakeDpiAware()
        {
            try { SetProcessDpiAwarenessContext(new IntPtr(-4)); } // PER_MONITOR_AWARE_V2
            catch (EntryPointNotFoundException) { }
        }

        public static bool LeftButtonDown() { return (GetAsyncKeyState(VkLButton) & 0x8000) != 0; }

        public static int CursorX()
        {
            Point p;
            GetCursorPos(out p);
            return p.X;
        }

        public static int CursorY()
        {
            Point p;
            GetCursorPos(out p);
            return p.Y;
        }

        // Display scale of the monitor under the cursor (1.0 at 100%, 1.25 at 125%).
        public static double CursorScale()
        {
            Point p;
            GetCursorPos(out p);
            uint dx, dy;
            IntPtr monitor = MonitorFromPoint(p, MonitorDefaultToNearest);
            if (monitor == IntPtr.Zero || GetDpiForMonitor(monitor, 0, out dx, out dy) != 0 || dx == 0) return 1.0;
            return dx / 96.0;
        }
    }
}
