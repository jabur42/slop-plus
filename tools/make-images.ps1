# Gera as imagens do canal Slop+ (logo, ícones, fundos, 9-patches e ícones do player).
# Uso: powershell -ExecutionPolicy Bypass -File tools\make-images.ps1
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$out = Join-Path (Split-Path -Parent $PSScriptRoot) 'roku\images'
New-Item -ItemType Directory -Force -Path $out | Out-Null

$BG = [Drawing.Color]::FromArgb(255, 14, 14, 18)
$ACCENT1 = [Drawing.Color]::FromArgb(255, 139, 92, 246)   # roxo claro
$ACCENT2 = [Drawing.Color]::FromArgb(255, 109, 40, 217)   # roxo escuro
$WHITE = [Drawing.Color]::White

function New-Canvas($w, $h) {
  $b = New-Object Drawing.Bitmap $w, $h, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [Drawing.Graphics]::FromImage($b)
  $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
  $g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'
  $g.Clear([Drawing.Color]::Transparent)
  return @{ b = $b; g = $g }
}
function Save($c, $name) { $c.g.Dispose(); $c.b.Save((Join-Path $out $name), [Drawing.Imaging.ImageFormat]::Png); $c.b.Dispose() }

function RoundRect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
  $p = New-Object Drawing.Drawing2D.GraphicsPath
  $d = $r * 2
  $p.AddArc($x, $y, $d, $d, 180, 90); $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90); $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $p.CloseFigure(); return $p
}

# Desenha o wordmark "Slop+" centralizado em (cx, cy) com altura de fonte $size
function Draw-Wordmark($g, [float]$cx, [float]$cy, [float]$size) {
  $font = New-Object Drawing.Font 'Segoe UI Black', $size, ([Drawing.FontStyle]::Regular), ([Drawing.GraphicsUnit]::Pixel)
  $fmt = [Drawing.StringFormat]::GenericTypographic
  $w1 = $g.MeasureString('Slop', $font, 10000, $fmt).Width
  $w2 = $g.MeasureString('+', $font, 10000, $fmt).Width
  $x = $cx - ($w1 + $w2 * 0.95) / 2
  $y = $cy - $size * 0.66
  $g.DrawString('Slop', $font, (New-Object Drawing.SolidBrush $WHITE), $x, $y, $fmt)
  $rect = New-Object Drawing.RectangleF ($x + $w1), $y, $w2, ($size * 1.3)
  $grad = New-Object Drawing.Drawing2D.LinearGradientBrush $rect, $ACCENT1, $ACCENT2, 90
  $g.DrawString('+', $font, $grad, $x + $w1 - $size * 0.02, $y, $fmt)
  $font.Dispose()
}

# ---------- logo (fundo transparente)
$c = New-Canvas 360 120; Draw-Wordmark $c.g 180 62 96; Save $c 'logo.png'

# ---------- ícones do canal (tela inicial do Roku)
foreach ($s in @(@{ w = 540; h = 405; f = 'icon_fhd.png' }, @{ w = 290; h = 218; f = 'icon_hd.png' })) {
  $c = New-Canvas $s.w $s.h
  $rect = New-Object Drawing.Rectangle 0, 0, $s.w, $s.h
  $grad = New-Object Drawing.Drawing2D.LinearGradientBrush $rect, ([Drawing.Color]::FromArgb(255, 24, 12, 48)), ([Drawing.Color]::FromArgb(255, 88, 32, 180)), 35
  $c.g.FillRectangle($grad, $rect)
  Draw-Wordmark $c.g ($s.w / 2) ($s.h / 2 + $s.h * 0.02) ($s.h * 0.30)
  Save $c $s.f
}

# ---------- splash
$c = New-Canvas 1920 1080
$c.g.Clear($BG)
$glow = New-Object Drawing.Drawing2D.GraphicsPath; $glow.AddEllipse(460, 140, 1000, 800)
$pb = New-Object Drawing.Drawing2D.PathGradientBrush $glow
$pb.CenterColor = [Drawing.Color]::FromArgb(90, 109, 40, 217); $pb.SurroundColors = @([Drawing.Color]::FromArgb(0, 14, 14, 18))
$c.g.FillPath($pb, $glow)
Draw-Wordmark $c.g 960 540 190
Save $c 'splash.png'

# ---------- sombras (fundo das telas e do player)
$c = New-Canvas 1920 1080
$left = New-Object Drawing.Rectangle 0, 0, 1400, 1080
$c.g.FillRectangle((New-Object Drawing.Drawing2D.LinearGradientBrush $left, ([Drawing.Color]::FromArgb(250, 14, 14, 18)), ([Drawing.Color]::FromArgb(0, 14, 14, 18)), 0), 0, 0, 1399, 1080)
$bottom = New-Object Drawing.Rectangle 0, 380, 1920, 701
$c.g.FillRectangle((New-Object Drawing.Drawing2D.LinearGradientBrush $bottom, ([Drawing.Color]::FromArgb(0, 14, 14, 18)), ([Drawing.Color]::FromArgb(255, 14, 14, 18)), 90), 0, 381, 1920, 699)
$top = New-Object Drawing.Rectangle 0, 0, 1920, 220
$c.g.FillRectangle((New-Object Drawing.Drawing2D.LinearGradientBrush $top, ([Drawing.Color]::FromArgb(170, 14, 14, 18)), ([Drawing.Color]::FromArgb(0, 14, 14, 18)), 90), 0, 0, 1920, 219)
Save $c 'shade.png'

$c = New-Canvas 1920 280
$r = New-Object Drawing.Rectangle 0, 0, 1920, 281
$c.g.FillRectangle((New-Object Drawing.Drawing2D.LinearGradientBrush $r, ([Drawing.Color]::FromArgb(210, 0, 0, 0)), ([Drawing.Color]::FromArgb(0, 0, 0, 0)), 90), 0, 0, 1920, 280)
Save $c 'top_shade.png'

$c = New-Canvas 1920 420
$r = New-Object Drawing.Rectangle 0, 0, 1920, 421
$c.g.FillRectangle((New-Object Drawing.Drawing2D.LinearGradientBrush $r, ([Drawing.Color]::FromArgb(0, 0, 0, 0)), ([Drawing.Color]::FromArgb(235, 0, 0, 0)), 90), 0, 0, 1920, 420)
Save $c 'bottom_shade.png'

# ---------- 9-patches (borda de 1px com marcadores pretos nas áreas esticáveis)
function Make-NinePatch($name, [scriptblock]$draw) {
  $n = 48; $c = New-Canvas ($n + 2) ($n + 2)
  & $draw $c.g 1 1 $n
  $black = [Drawing.Color]::FromArgb(255, 0, 0, 0)
  for ($i = 17; $i -le 32; $i++) { $c.b.SetPixel($i, 0, $black); $c.b.SetPixel(0, $i, $black) }
  Save $c $name
}
Make-NinePatch 'pill.9.png' { param($g, $x, $y, $n) $g.FillPath((New-Object Drawing.SolidBrush $WHITE), (RoundRect $x $y $n $n 14)) }
Make-NinePatch 'ring.9.png' { param($g, $x, $y, $n)
  $pen = New-Object Drawing.Pen $WHITE, 4; $g.DrawPath($pen, (RoundRect ($x + 2) ($y + 2) ($n - 4) ($n - 4) 10)) }
Make-NinePatch 'rowfocus.9.png' { param($g, $x, $y, $n)
  $g.FillPath((New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(255, 44, 44, 56))), (RoundRect $x $y $n $n 14))
  $pen = New-Object Drawing.Pen $WHITE, 3; $g.DrawPath($pen, (RoundRect ($x + 1.5) ($y + 1.5) ($n - 3) ($n - 3) 13)) }

# ---------- formas
$c = New-Canvas 128 128; $c.g.FillEllipse((New-Object Drawing.SolidBrush $WHITE), 1, 1, 126, 126); Save $c 'circle.png'

$c = New-Canvas 128 128
$pen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(50, 255, 255, 255)), 10; $c.g.DrawEllipse($pen, 10, 10, 108, 108)
$pen = New-Object Drawing.Pen $ACCENT1, 10; $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
$c.g.DrawArc($pen, 10, 10, 108, 108, -90, 100)
Save $c 'spinner.png'

# ---------- ícones do player (brancos, 96x96)
function Icon($name, [scriptblock]$draw) { $c = New-Canvas 96 96; & $draw $c.g; Save $c $name }
$wb = New-Object Drawing.SolidBrush $WHITE
Icon 'ic_play.png' { param($g) $g.FillPolygon($wb, [Drawing.PointF[]]@((New-Object Drawing.PointF 30, 18), (New-Object Drawing.PointF 80, 48), (New-Object Drawing.PointF 30, 78))) }
Icon 'ic_pause.png' { param($g) $g.FillPath($wb, (RoundRect 24 18 16 60 4)); $g.FillPath($wb, (RoundRect 56 18 16 60 4)) }
function Draw-Skip($g, [bool]$fwd) {
  $pen = New-Object Drawing.Pen $WHITE, 7; $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
  if ($fwd) { $g.DrawArc($pen, 14, 14, 68, 68, -60, 300); $tip = @((New-Object Drawing.PointF 58, 4), (New-Object Drawing.PointF 76, 22), (New-Object Drawing.PointF 54, 30)) }
  else { $g.DrawArc($pen, 14, 14, 68, 68, -120, -300); $tip = @((New-Object Drawing.PointF 38, 4), (New-Object Drawing.PointF 20, 22), (New-Object Drawing.PointF 42, 30)) }
  $g.FillPolygon($wb, [Drawing.PointF[]]$tip)
  $f = New-Object Drawing.Font 'Segoe UI', 26, ([Drawing.FontStyle]::Bold), ([Drawing.GraphicsUnit]::Pixel)
  $sf = New-Object Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
  $g.DrawString('10', $f, $wb, (New-Object Drawing.RectangleF 0, 2, 96, 96), $sf)
}
Icon 'ic_rew.png' { param($g) Draw-Skip $g $false }
Icon 'ic_fwd.png' { param($g) Draw-Skip $g $true }
function Draw-TextIcon($g, $text, $size, [bool]$box) {
  if ($box) { $pen = New-Object Drawing.Pen $WHITE, 6; $g.DrawPath($pen, (RoundRect 10 20 76 56 10)) }
  $f = New-Object Drawing.Font 'Segoe UI', $size, ([Drawing.FontStyle]::Bold), ([Drawing.GraphicsUnit]::Pixel)
  $sf = New-Object Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
  $g.DrawString($text, $f, $wb, (New-Object Drawing.RectangleF 0, 2, 96, 96), $sf)
}
Icon 'ic_cc.png' { param($g) Draw-TextIcon $g 'CC' 30 $true }
Icon 'ic_style.png' { param($g) Draw-TextIcon $g 'Aa' 44 $false }
Icon 'ic_audio.png' { param($g)
  $g.FillPolygon($wb, [Drawing.PointF[]]@((New-Object Drawing.PointF 14, 36), (New-Object Drawing.PointF 30, 36), (New-Object Drawing.PointF 50, 18), (New-Object Drawing.PointF 50, 78), (New-Object Drawing.PointF 30, 60), (New-Object Drawing.PointF 14, 60)))
  $pen = New-Object Drawing.Pen $WHITE, 6; $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
  $g.DrawArc($pen, 44, 30, 26, 36, -55, 110); $g.DrawArc($pen, 44, 16, 42, 64, -55, 110) }
Icon 'ic_search.png' { param($g)
  $pen = New-Object Drawing.Pen $WHITE, 8; $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
  $g.DrawEllipse($pen, 14, 14, 50, 50); $g.DrawLine($pen, 58, 58, 82, 82) }

Get-ChildItem $out | Select-Object Name, Length | Format-Table -AutoSize | Out-String
