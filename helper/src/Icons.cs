// Extracts an app's icon once and caches it as a PNG.

using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;

namespace AppMixer
{
    static class Icons
    {
        // Returns the icon path relative to the skin's @Resources folder, or null when no icon could be extracted.
        public static string Cache(string process, string exePath, string iconsDir)
        {
            if (exePath == null) return null;
            string file = Sanitize(process) + ".png";
            string target = Path.Combine(iconsDir, file);
            if (!File.Exists(target) && !Extract(exePath, target)) return null;
            return "Icons/" + file;
        }

        static bool Extract(string exePath, string target)
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(target));
                using (Bitmap bitmap = LoadIcon(exePath))
                {
                    if (bitmap == null) return false;
                    string temp = target + ".tmp";
                    bitmap.Save(temp, ImageFormat.Png);
                    File.Move(temp, target);
                }
                return true;
            }
            catch (Exception) { return false; }
        }

        // 64 px icon when the file has one, otherwise the shell's default size.
        static Bitmap LoadIcon(string exePath)
        {
            var handles = new IntPtr[1];
            var ids = new uint[1];
            uint got = Native.PrivateExtractIcons(exePath, 0, 64, 64, handles, ids, 1, 0);
            if (got > 0 && handles[0] != IntPtr.Zero)
            {
                try { using (Icon icon = Icon.FromHandle(handles[0])) return new Bitmap(icon.ToBitmap()); }
                finally { Native.DestroyIcon(handles[0]); }
            }
            using (Icon fallback = Icon.ExtractAssociatedIcon(exePath))
                return fallback == null ? null : new Bitmap(fallback.ToBitmap());
        }

        static string Sanitize(string name)
        {
            foreach (char c in Path.GetInvalidFileNameChars()) name = name.Replace(c, '_');
            return name.ToLowerInvariant();
        }
    }
}
