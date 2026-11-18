$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @'
using System;
public static class BeaverAlphaMask
{
    public static void Apply(byte[] pixels, int width, int height, int stride)
    {
        int[] corner = { 0, (width - 1) * 4, (height - 1) * stride, (height - 1) * stride + (width - 1) * 4 };
        for (int y = 0; y < height; y++)
        {
            double fy = height <= 1 ? 0.0 : (double)y / (height - 1);
            for (int x = 0; x < width; x++)
            {
                double fx = width <= 1 ? 0.0 : (double)x / (width - 1);
                int p = y * stride + x * 4;
                double db = pixels[p] - Lerp(corner, pixels, 0, fx, fy);
                double dg = pixels[p + 1] - Lerp(corner, pixels, 1, fx, fy);
                double dr = pixels[p + 2] - Lerp(corner, pixels, 2, fx, fy);
                double distance = Math.Sqrt(db * db + dg * dg + dr * dr);
                double keep = Math.Clamp((distance - 12.0) / 34.0, 0.0, 1.0);
                pixels[p + 3] = (byte)Math.Round(pixels[p + 3] * keep);
            }
        }
    }

    private static double Lerp(int[] c, byte[] p, int channel, double x, double y)
    {
        double tl = p[c[0] + channel], tr = p[c[1] + channel];
        double bl = p[c[2] + channel], br = p[c[3] + channel];
        return (tl * (1.0 - x) + tr * x) * (1.0 - y) + (bl * (1.0 - x) + br * x) * y;
    }
}
'@

function Export-SpriteFrame([System.Drawing.Bitmap]$Sheet, [string]$Path, [int]$X, [int]$Y, [int]$Width, [int]$Height) {
    $crop = [System.Drawing.Bitmap]::new($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($crop)
    try {
        $graphics.DrawImage($Sheet, [System.Drawing.Rectangle]::new(0, 0, $Width, $Height), [System.Drawing.Rectangle]::new($X, $Y, $Width, $Height), [System.Drawing.GraphicsUnit]::Pixel)
    } finally { $graphics.Dispose() }
    $rect = [System.Drawing.Rectangle]::new(0, 0, $Width, $Height)
    $data = $crop.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $length = $data.Stride * $Height
        $bytes = [byte[]]::new($length)
        [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $length)
        [BeaverAlphaMask]::Apply($bytes, $Width, $Height, $data.Stride)
        [System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $data.Scan0, $length)
    } finally { $crop.UnlockBits($data) }
    $crop.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $crop.Dispose()
}

$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root 'assets\characters\beaver_reference_sheet.png'
$output = Join-Path $root 'assets\characters\beaver'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$sheet = [System.Drawing.Bitmap]::new($source)
try {
    $animations = @{
        idle = @(@(344, 54, 112, 140), @(456, 54, 112, 140), @(568, 54, 112, 140), @(680, 54, 112, 140))
        walk = @(@(344, 252, 112, 142), @(456, 252, 112, 142), @(568, 252, 112, 142), @(680, 252, 112, 142))
        run = @(@(858, 54, 106, 142), @(964, 54, 106, 142), @(1070, 54, 106, 142), @(1176, 54, 106, 142), @(1282, 54, 106, 142), @(1388, 54, 106, 142))
        dig = @(@(14, 648, 142, 140), @(164, 648, 142, 140), @(314, 648, 142, 140), @(464, 648, 142, 140))
        fall = @(@(14, 448, 132, 144), @(154, 448, 132, 144), @(294, 448, 132, 144), @(434, 448, 132, 144))
        hurt = @(@(624, 454, 140, 140), @(770, 454, 140, 140), @(916, 454, 140, 140))
        die = @(@(1124, 454, 130, 140), @(1256, 454, 130, 140), @(1388, 454, 130, 140))
        celebrate = @(@(1044, 836, 152, 166), @(1204, 836, 152, 166), @(1364, 836, 152, 166))
    }
    foreach ($animation in $animations.Keys) {
        for ($i = 0; $i -lt $animations[$animation].Count; $i++) {
            $frame = $animations[$animation][$i]
            Export-SpriteFrame $sheet (Join-Path $output ('{0}_{1}.png' -f $animation, $i)) $frame[0] $frame[1] $frame[2] $frame[3]
        }
    }
    Export-SpriteFrame $sheet (Join-Path $output 'portrait.png') 8 8 322 352
} finally { $sheet.Dispose() }
