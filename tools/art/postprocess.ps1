param([string]$Manifest = "$PSScriptRoot/generation-manifest.json")
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
public static class HouseRulesArt {
    // HOUSE-RULES-16, excluding currency gold and table-only felt for this batch.
    static readonly string[] Hex = {"0B0A12","1A1826","2D2A3E","474259","6B7280","A9A4BF","E8E6F0","FFFFFF","FF3D7F","00E5FF","9D4DFF","FF8A3D","39FF6A","FF4D4D"};
    public static void Process(string input, string output, int width, int height) {
        Color[] palette = Array.ConvertAll(Hex, h => ColorTranslator.FromHtml("#" + h));
        using (Bitmap source = new Bitmap(input))
        using (Bitmap target = new Bitmap(width, height, PixelFormat.Format32bppArgb)) {
            for (int y = 0; y < height; y++) for (int x = 0; x < width; x++) {
                // Explicit center-sampled nearest neighbour: no interpolation or dithering.
                int sx = Math.Min(source.Width-1, (int)((x+0.5)*source.Width/width));
                int sy = Math.Min(source.Height-1, (int)((y+0.5)*source.Height/height));
                Color pixel = source.GetPixel(sx,sy), best = palette[0];
                int distance = Int32.MaxValue;
                foreach (Color p in palette) {
                    int r = pixel.R-p.R, g = pixel.G-p.G, b = pixel.B-p.B;
                    int d = r*r+g*g+b*b;
                    if (d < distance) { distance = d; best = p; }
                }
                target.SetPixel(x,y,Color.FromArgb(pixel.A < 128 ? 0 : 255,best));
            }
            target.Save(output,ImageFormat.Png);
        }
    }
    public static string Validate(string input, int width, int height) {
        using (Bitmap image = new Bitmap(input)) {
            if (image.Width != width || image.Height != height) throw new Exception("Wrong dimensions");
            var colors = new System.Collections.Generic.HashSet<int>();
            int transparent = 0;
            for (int y=0;y<height;y++) for(int x=0;x<width;x++) {
                Color p=image.GetPixel(x,y);
                if (p.A==0) { transparent++; continue; }
                if (p.A!=255) throw new Exception("Partial alpha");
                string h=p.R.ToString("X2")+p.G.ToString("X2")+p.B.ToString("X2");
                if(Array.IndexOf(Hex,h)<0) throw new Exception("Outside allowed palette: "+h);
                colors.Add(p.ToArgb());
            }
            return width+"x"+height+", "+colors.Count+" palette colors, "+transparent+" transparent pixels";
        }
    }
}
'@
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$data = Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json
$results = foreach ($asset in $data.assets) {
    $source = Join-Path $root $asset.raw_path
    $target = Join-Path $root $asset.processed_path
    [HouseRulesArt]::Process($source, $target, $asset.width, $asset.height)
    [PSCustomObject]@{asset=$asset.asset; validation=[HouseRulesArt]::Validate($target,$asset.width,$asset.height); sha256=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash; manual_cleanup_accepted=$false}
}
$results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'validation.json') -Encoding UTF8
$results | Format-Table asset,validation -AutoSize
