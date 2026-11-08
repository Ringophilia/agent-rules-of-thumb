<#
.SYNOPSIS
  Stitch several screenshots into ONE labelled grid image (a contact sheet) so a
  vision model can compare them in a single look: before/after, a time series, or
  several windows side by side. Optional -Diff marks what changed between two shots.

  Why: a model compares regions inside one image far more reliably than across
  separate images, and one grid costs about as many tokens as one screenshot
  (Claude bills images by area and scales anything over ~1568 px / ~1.15 MP down).
  Trade-off: each tile gets less resolution. Use a grid to compare layout/state;
  to READ small text use a single crop, or read the text itself (UIA, DOM, logs).

.EXAMPLES
  # Grid of any shots ("||" separates items; with powershell -File arrays collapse)
  compose-shots.ps1 -Inputs "a.png||b.png||c.png||d.png" -Labels "start||loading||done||error" -Out grid.png

  # Before / after with changed regions boxed in red (3 tiles: before, after, changes)
  compose-shots.ps1 -Inputs "before.png||after.png" -Diff -Out diff.png -Title "after clicking Save"

  # Wildcards work; files are taken in name order
  compose-shots.ps1 -Inputs "C:\tmp\frames\*.png" -Out sheet.png

.PARAMETERS
  -Columns     force the number of columns (default: chosen to make tiles as large as possible)
  -MaxEdge     longest edge of the result in px (default 1568, Claude's no-downscale limit)
  -MaxPixels   pixel budget of the result (default 1150000, ~1.5k image tokens)
  -Threshold   -Diff sensitivity: per-pixel sum of |dR|+|dG|+|dB| that counts as changed (default 60)
  -Title       optional header line

  Prints one JSON line: output path, size, layout, per-tile scale, and with -Diff the
  changed boxes in the AFTER image's own pixel coordinates plus the changed percentage.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string[]]$Inputs,
  [string[]]$Labels,
  [Parameter(Mandatory)][string]$Out,
  [int]$Columns = 0,
  [int]$MaxEdge = 1568,
  [int]$MaxPixels = 1150000,
  [switch]$Diff,
  [int]$Threshold = 60,
  [string]$Title
)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

$src = @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

public static class ShotComposer {
  const int GAP = 6, LABEL_H = 24, TITLE_H = 30, BLOCK = 8;

  public static Bitmap Load(string p) {
    using (var fs = new FileStream(p, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
    using (var img = Image.FromStream(fs))
      return new Bitmap(img);
  }

  // ---------------- diff ----------------
  static byte[] Pixels(Bitmap b, out int stride) {
    var d = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
    stride = d.Stride; var buf = new byte[stride * b.Height];
    Marshal.Copy(d.Scan0, buf, 0, buf.Length); b.UnlockBits(d); return buf;
  }

  // Returns changed boxes (in b's pixel coords) and the changed-pixel percentage.
  public static List<Rectangle> DiffBoxes(Bitmap a, Bitmap b, int threshold, out double pct) {
    Bitmap a2 = a;
    if (a.Width != b.Width || a.Height != b.Height) {
      a2 = new Bitmap(b.Width, b.Height, PixelFormat.Format32bppArgb);
      using (var g = Graphics.FromImage(a2)) { g.InterpolationMode = InterpolationMode.HighQualityBilinear; g.DrawImage(a, 0, 0, b.Width, b.Height); }
    }
    int sa, sb; var pa = Pixels(a2, out sa); var pb = Pixels(b, out sb);
    if (!ReferenceEquals(a2, a)) a2.Dispose();
    int bw = (b.Width + BLOCK - 1) / BLOCK, bh = (b.Height + BLOCK - 1) / BLOCK;
    var grid = new bool[bw, bh]; long changed = 0, total = 0;
    for (int y = 0; y < b.Height; y++) {
      int oa = y * sa, ob = y * sb;
      for (int x = 0; x < b.Width; x++) {
        int i = x * 4;
        int dsum = Math.Abs(pa[oa + i] - pb[ob + i]) + Math.Abs(pa[oa + i + 1] - pb[ob + i + 1]) + Math.Abs(pa[oa + i + 2] - pb[ob + i + 2]);
        total++;
        if (dsum > threshold) { changed++; grid[x / BLOCK, y / BLOCK] = true; }
      }
    }
    pct = total == 0 ? 0 : 100.0 * changed / total;
    // dilate by one block so nearby changes merge into one box
    var dil = new bool[bw, bh];
    for (int x = 0; x < bw; x++) for (int y = 0; y < bh; y++) if (grid[x, y])
      for (int dx = -1; dx <= 1; dx++) for (int dy = -1; dy <= 1; dy++) {
        int nx = x + dx, ny = y + dy; if (nx >= 0 && ny >= 0 && nx < bw && ny < bh) dil[nx, ny] = true; }
    var seen = new bool[bw, bh]; var boxes = new List<Rectangle>(); var st = new Stack<Point>();
    for (int x = 0; x < bw; x++) for (int y = 0; y < bh; y++) {
      if (!dil[x, y] || seen[x, y]) continue;
      int x0 = x, y0 = y, x1 = x, y1 = y; bool real = false;
      st.Push(new Point(x, y)); seen[x, y] = true;
      while (st.Count > 0) {
        var p = st.Pop();
        if (grid[p.X, p.Y]) { real = true; x0 = Math.Min(x0, p.X); y0 = Math.Min(y0, p.Y); x1 = Math.Max(x1, p.X); y1 = Math.Max(y1, p.Y); }
        for (int dx = -1; dx <= 1; dx++) for (int dy = -1; dy <= 1; dy++) {
          int nx = p.X + dx, ny = p.Y + dy;
          if (nx >= 0 && ny >= 0 && nx < bw && ny < bh && dil[nx, ny] && !seen[nx, ny]) { seen[nx, ny] = true; st.Push(new Point(nx, ny)); }
        }
      }
      if (!real) continue;
      int rx = x0 * BLOCK, ry = y0 * BLOCK;
      boxes.Add(new Rectangle(rx, ry, Math.Min(b.Width, (x1 + 1) * BLOCK) - rx, Math.Min(b.Height, (y1 + 1) * BLOCK) - ry));
    }
    boxes.Sort((p, q) => (q.Width * q.Height).CompareTo(p.Width * p.Height));
    if (boxes.Count > 40) boxes.RemoveRange(40, boxes.Count - 40);
    return boxes;
  }

  // "changes" tile: dim everything that did not change.
  public static Bitmap Highlight(Bitmap b, List<Rectangle> boxes) {
    var r = new Bitmap(b.Width, b.Height, PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(r)) {
      g.DrawImage(b, 0, 0, b.Width, b.Height);
      using (var dim = new SolidBrush(Color.FromArgb(170, 0, 0, 0))) {
        var region = new Region(new Rectangle(0, 0, b.Width, b.Height));
        foreach (var x in boxes) region.Exclude(x);
        g.FillRegion(dim, region);
      }
    }
    return r;
  }

  // ---------------- layout ----------------
  static double ScaleFor(int n, int cols, int cw, int ch, int maxEdge, int maxPixels, int titleH) {
    int rows = (n + cols - 1) / cols;
    double s1 = (maxEdge - (cols + 1) * GAP) / (double)(cols * cw);
    double s2 = (maxEdge - titleH - (rows + 1) * GAP - rows * LABEL_H) / (double)(rows * ch);
    double s = Math.Min(1.0, Math.Min(s1, s2));
    while (s > 0.02) {
      double W = cols * cw * s + (cols + 1) * GAP, H = titleH + rows * (ch * s + LABEL_H) + (rows + 1) * GAP;
      if (W * H <= maxPixels) break;
      s *= 0.98;
    }
    return s;
  }

  public static string Compose(Bitmap[] tiles, string[] labels, List<Rectangle>[] boxes, string outPath,
                               int cols, int maxEdge, int maxPixels, string title, out string layout, out double scale, out Size size) {
    int n = tiles.Length, cw = 1, ch = 1;
    foreach (var t in tiles) { cw = Math.Max(cw, t.Width); ch = Math.Max(ch, t.Height); }
    int titleH = string.IsNullOrEmpty(title) ? 0 : TITLE_H;
    if (cols <= 0) {
      // Largest tiles win; on (near) ties prefer a screen-like landscape shape, then fewer empty cells.
      double bestS = -1, bestTie = double.MaxValue;
      for (int c = 1; c <= n; c++) {
        double s = ScaleFor(n, c, cw, ch, maxEdge, maxPixels, titleH);
        int rr = (n + c - 1) / c, empty = rr * c - n;
        double w = c * cw * s + (c + 1) * GAP, h = titleH + rr * (ch * s + LABEL_H) + (rr + 1) * GAP;
        double tie = Math.Abs(Math.Log(w / h) - Math.Log(1.6)) + empty * 0.05;
        if (s > bestS * 1.01 || (s >= bestS * 0.99 && tie < bestTie)) { bestS = Math.Max(s, bestS); bestTie = tie; cols = c; }
      }
    }
    cols = Math.Min(cols, n);
    int rows = (n + cols - 1) / cols;
    scale = ScaleFor(n, cols, cw, ch, maxEdge, maxPixels, titleH);
    int cellW = (int)Math.Floor(cw * scale), cellH = (int)Math.Floor(ch * scale);
    int W = cols * cellW + (cols + 1) * GAP, H = titleH + rows * (cellH + LABEL_H) + (rows + 1) * GAP;
    size = new Size(W, H); layout = cols + "x" + rows;

    using (var canvas = new Bitmap(W, H, PixelFormat.Format24bppRgb))
    using (var g = Graphics.FromImage(canvas))
    using (var font = new Font("Segoe UI", 10f, FontStyle.Bold, GraphicsUnit.Point))
    using (var tfont = new Font("Segoe UI", 12f, FontStyle.Bold, GraphicsUnit.Point))
    using (var labelBg = new SolidBrush(Color.FromArgb(48, 48, 52)))
    using (var numBg = new SolidBrush(Color.FromArgb(0, 120, 212)))
    using (var white = new SolidBrush(Color.White))
    using (var red = new Pen(Color.FromArgb(255, 40, 40), 2f))
    using (var border = new Pen(Color.FromArgb(90, 90, 96), 1f)) {
      g.Clear(Color.FromArgb(28, 28, 30));
      g.InterpolationMode = InterpolationMode.HighQualityBicubic;
      g.PixelOffsetMode = PixelOffsetMode.HighQuality;
      g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
      var fmt = new StringFormat { LineAlignment = StringAlignment.Center, Trimming = StringTrimming.EllipsisCharacter, FormatFlags = StringFormatFlags.NoWrap };
      if (titleH > 0) g.DrawString(title, tfont, white, new RectangleF(GAP + 2, 0, W - 2 * GAP, titleH), fmt);
      for (int i = 0; i < n; i++) {
        int c = i % cols, r = i / cols;
        int x = GAP + c * (cellW + GAP), y = titleH + GAP + r * (cellH + LABEL_H + GAP);
        // label strip: [ n ] label
        g.FillRectangle(labelBg, x, y, cellW, LABEL_H);
        string num = (i + 1).ToString();
        int nw = Math.Max(LABEL_H, (int)g.MeasureString(num, font).Width + 8);
        g.FillRectangle(numBg, x, y, nw, LABEL_H);
        var cf = new StringFormat(fmt) { Alignment = StringAlignment.Center };
        g.DrawString(num, font, white, new RectangleF(x, y, nw, LABEL_H), cf);
        string lab = (labels != null && i < labels.Length) ? labels[i] : "";
        g.DrawString(lab, font, white, new RectangleF(x + nw + 6, y, cellW - nw - 8, LABEL_H), fmt);
        // tile, fitted into the cell keeping aspect ratio
        var t = tiles[i];
        double ts = Math.Min(cellW / (double)t.Width, cellH / (double)t.Height);
        int tw = (int)(t.Width * ts), th = (int)(t.Height * ts);
        int tx = x + (cellW - tw) / 2, ty = y + LABEL_H + (cellH - th) / 2;
        g.DrawImage(t, tx, ty, tw, th);
        g.DrawRectangle(border, tx - 1, ty - 1, tw + 1, th + 1);
        if (boxes != null && boxes[i] != null)
          foreach (var bx in boxes[i])
            g.DrawRectangle(red, tx + (float)(bx.X * ts), ty + (float)(bx.Y * ts), Math.Max(2f, (float)(bx.Width * ts)), Math.Max(2f, (float)(bx.Height * ts)));
      }
      canvas.Save(outPath, ImageFormat.Png);
    }
    return outPath;
  }
}
"@
if (-not ('ShotComposer' -as [type])) { Add-Type -TypeDefinition $src -ReferencedAssemblies System.Drawing }

function Split-Items([string[]]$items, [switch]$Paths) {
  $out = New-Object System.Collections.Generic.List[string]
  foreach ($chunk in $items) {
    foreach ($part in ($chunk -split '\s*\|\|\s*')) {
      if ($part -eq '') { continue }
      if ($Paths) {
        if ($part -match '[\*\?]') {
          Get-ChildItem -Path $part -File | Sort-Object Name | ForEach-Object { $out.Add($_.FullName) }
        } elseif (-not (Test-Path -LiteralPath $part) -and $part.Contains(',')) {
          # "powershell -File" joined an array with commas
          $part.Split(',') | Where-Object { $_ } | ForEach-Object { $out.Add($_.Trim()) }
        } else { $out.Add($part) }
      } else { $out.Add($part) }
    }
  }
  ,$out.ToArray()
}

$paths = Split-Items $Inputs -Paths
if ($paths.Count -eq 0) { throw 'No input images.' }
foreach ($p in $paths) { if (-not (Test-Path -LiteralPath $p)) { throw "Input not found: $p" } }
$labs = if ($Labels) { Split-Items $Labels } else { @() }
if ($Labels -and $labs.Count -ne $paths.Count -and $labs.Count -eq 1 -and $labs[0].Contains(',')) { $labs = $labs[0].Split(',') }

$outFull = [IO.Path]::GetFullPath($Out)
$dir = [IO.Path]::GetDirectoryName($outFull)
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }

$bitmaps = @($paths | ForEach-Object { [ShotComposer]::Load((Resolve-Path -LiteralPath $_).Path) })
$extra = @()
$result = [ordered]@{}
try {
  $tiles = $bitmaps; $boxes = $null
  if ($Diff) {
    if ($bitmaps.Count -ne 2) { throw '-Diff needs exactly 2 inputs (before, after).' }
    $pct = 0.0
    $found = [ShotComposer]::DiffBoxes($bitmaps[0], $bitmaps[1], $Threshold, [ref]$pct)
    $hl = [ShotComposer]::Highlight($bitmaps[1], $found); $extra += $hl
    $tiles = @($bitmaps[0], $bitmaps[1], $hl)
    # boxes are in AFTER coords; map onto BEFORE if its size differs
    $sx = $bitmaps[0].Width / $bitmaps[1].Width; $sy = $bitmaps[0].Height / $bitmaps[1].Height
    $beforeBoxes = New-Object 'System.Collections.Generic.List[System.Drawing.Rectangle]'
    foreach ($r in $found) { $beforeBoxes.Add((New-Object System.Drawing.Rectangle ([int]($r.X*$sx)), ([int]($r.Y*$sy)), ([int]($r.Width*$sx)), ([int]($r.Height*$sy)))) }
    $boxes = [System.Collections.Generic.List[System.Drawing.Rectangle][]]@($beforeBoxes, $found, $found)
    if (-not $Labels) { $labs = @('before', 'after', ('changes: {0} region(s), {1:N1}% of pixels' -f $found.Count, $pct)) }
    elseif ($labs.Count -lt 3) { $labs = @($labs) + @(('changes: {0} region(s), {1:N1}% of pixels' -f $found.Count, $pct)) }
    $result.changedPercent = [math]::Round($pct, 2)
    $result.changedBoxes = @($found | ForEach-Object { [ordered]@{ x = $_.X; y = $_.Y; w = $_.Width; h = $_.Height } })
  }
  $layout = ''; $scale = 0.0; $size = New-Object System.Drawing.Size
  [void][ShotComposer]::Compose([System.Drawing.Bitmap[]]$tiles, [string[]]$labs, $boxes, $outFull, $Columns, $MaxEdge, $MaxPixels, $Title, [ref]$layout, [ref]$scale, [ref]$size)
  $ordered = [ordered]@{
    path = $outFull; width = $size.Width; height = $size.Height; layout = $layout
    tileScale = [math]::Round($scale, 3); tiles = $tiles.Count
    approxTokens = [int]($size.Width * $size.Height / 750)
  }
  foreach ($k in $result.Keys) { $ordered[$k] = $result[$k] }
  $ordered | ConvertTo-Json -Compress -Depth 4
} finally {
  foreach ($b in $bitmaps + $extra) { if ($b) { $b.Dispose() } }
}
