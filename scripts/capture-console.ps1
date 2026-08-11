param([Parameter(Mandatory = $true)][string]$LogPath)

$ErrorActionPreference = 'Stop'
if (-not ('Lithica.ConsoleCapture' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace Lithica {
    [StructLayout(LayoutKind.Sequential)]
    public struct Coord {
        public short X;
        public short Y;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct SmallRect {
        public short Left;
        public short Top;
        public short Right;
        public short Bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct ScreenBufferInfo {
        public Coord Size;
        public Coord CursorPosition;
        public short Attributes;
        public SmallRect Window;
        public Coord MaximumWindowSize;
    }

    public static class ConsoleCapture {
        [DllImport("kernel32.dll", SetLastError = true)]
        static extern IntPtr GetStdHandle(int handle);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool GetConsoleScreenBufferInfo(
            IntPtr output,
            out ScreenBufferInfo info
        );

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        static extern bool ReadConsoleOutputCharacter(
            IntPtr output,
            StringBuilder buffer,
            uint length,
            Coord coordinate,
            out uint read
        );

        public static string ReadVisibleHistory() {
            IntPtr output = GetStdHandle(-11);
            ScreenBufferInfo info;
            if (!GetConsoleScreenBufferInfo(output, out info)) {
                throw new InvalidOperationException("No se pudo leer el buffer de la consola.");
            }

            int width = info.Size.X;
            int lastRow = info.CursorPosition.Y;
            var result = new StringBuilder();
            for (short row = 0; row <= lastRow; row++) {
                var line = new StringBuilder(width);
                uint read;
                var coordinate = new Coord { X = 0, Y = row };
                if (!ReadConsoleOutputCharacter(
                    output,
                    line,
                    (uint)width,
                    coordinate,
                    out read
                )) {
                    continue;
                }
                result.AppendLine(line.ToString().TrimEnd());
            }
            return result.ToString().TrimEnd();
        }
    }
}
'@
}

$directory = Split-Path -Parent $LogPath
New-Item -ItemType Directory -Force -Path $directory | Out-Null
$snapshot = [Lithica.ConsoleCapture]::ReadVisibleHistory()
Add-Content -LiteralPath $LogPath -Encoding UTF8 -Value @(
    ''
    '================ CONSOLA COMPLETA ================'
    $snapshot
    '================ FIN DE CONSOLA =================='
)

