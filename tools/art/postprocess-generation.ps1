param([string]$Manifest = "$PSScriptRoot/m2-generation-manifest.json")
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
public static class HouseRulesM2Art {
    static readonly string[] Hex = {
        "0B0A12","1A1826","2D2A3E","474259","6B7280","A9A4BF","E8E6F0","FFFFFF",
        "FF3D7F","00E5FF","9D4DFF","FFD23F","FF8A3D","39FF6A","FF4D4D","123A2E"
    };
    public static string Process(string input, string output, int width, int height) {
        Color[] palette = Array.ConvertAll(Hex, h => ColorTranslator.FromHtml("#" + h));
        using (Bitmap source = new Bitmap(input))
        using (Bitmap target = new Bitmap(width, height, PixelFormat.Format32bppArgb)) {
            double targetRatio = (double)width / height;
            double sourceRatio = (double)source.Width / source.Height;
            int cropW = source.Width, cropH = source.Height, offsetX = 0, offsetY = 0;
            if (sourceRatio > targetRatio) {
                cropW = Math.Max(1, (int)Math.Round(source.Height * targetRatio));
                offsetX = (source.Width - cropW) / 2;
            } else if (sourceRatio < targetRatio) {
                cropH = Math.Max(1, (int)Math.Round(source.Width / targetRatio));
                offsetY = (source.Height - cropH) / 2;
            }
            for (int y = 0; y < height; y++) for (int x = 0; x < width; x++) {
                int sx = offsetX + Math.Min(cropW - 1, (int)((x + 0.5) * cropW / width));
                int sy = offsetY + Math.Min(cropH - 1, (int)((y + 0.5) * cropH / height));
                Color pixel = source.GetPixel(sx, sy), best = palette[0];
                int distance = Int32.MaxValue;
                foreach (Color p in palette) {
                    int r = pixel.R-p.R, g = pixel.G-p.G, b = pixel.B-p.B;
                    int d = r*r+g*g+b*b;
                    if (d < distance) { distance = d; best = p; }
                }
                target.SetPixel(x, y, Color.FromArgb(255, best));
            }
            target.Save(output, ImageFormat.Png);
            return source.Width + "x" + source.Height;
        }
    }
    public static string Validate(string input, int width, int height) {
        using (Bitmap image = new Bitmap(input)) {
            if (image.Width != width || image.Height != height) throw new Exception("Wrong dimensions");
            var colors = new System.Collections.Generic.HashSet<int>();
            for (int y=0; y<height; y++) for(int x=0; x<width; x++) {
                Color p=image.GetPixel(x,y);
                string h=p.R.ToString("X2")+p.G.ToString("X2")+p.B.ToString("X2");
                if(Array.IndexOf(Hex,h)<0) throw new Exception("Outside allowed palette: "+h);
                colors.Add(p.ToArgb());
            }
            return width+"x"+height+", "+colors.Count+" palette colors";
        }
    }
}
'@
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$data = Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json
$draftDirectory = Join-Path $root 'assets/drafts/m2'
New-Item -ItemType Directory -Force -Path $draftDirectory | Out-Null
$results = foreach ($asset in $data.assets | Where-Object type -eq 'image') {
    $source = Join-Path $root $asset.path
    $target = Join-Path $draftDirectory "$($asset.asset).png"
    $sourceSize = [HouseRulesM2Art]::Process(
        $source, $target, $asset.target_width, $asset.target_height
    )
    [PSCustomObject]@{
        asset = $asset.asset
        source_dimensions = $sourceSize
        validation = [HouseRulesM2Art]::Validate(
            $target, $asset.target_width, $asset.target_height
        )
        sha256 = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
        acceptance_status = 'visual_cleanup_pending'
    }
}
$validation = Join-Path $PSScriptRoot 'm2-validation.json'
$results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $validation -Encoding UTF8
$results | Format-Table asset,source_dimensions,validation -AutoSize
