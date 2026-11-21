# 录宣传片：开窗口按顺序演一遍 tests/reel 里的整片，用 Godot 的录影模式存成 AVI，再转 MP4。
# 声音是游戏自己的音乐和音效，不另外配乐。会弹出游戏窗口，演完自己关。
# 用法（在 farm-town/ 下）：powershell -File tools\record_trailer.ps1 [-Part trailer] [-Fps 30]
# -Part 可以是 trailer 或单段名字（field、fish、mine……），单段用来试镜头。
param(
	[string]$Part = "trailer",
	[int]$Fps = 30,
	[string]$Out = "_preview\trailer"
)

$godot = "E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
$ffmpeg = & "D:\Miniconda3\python.exe" -c "import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())"
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$avi = Join-Path $Out "$Part.avi"
$mp4 = Join-Path $Out "$Part.mp4"
Remove-Item $avi, $mp4 -ErrorAction SilentlyContinue

# 项目里写死了窗口 1152x648，命令行的 --resolution 压不过它。
# 384x216 的 5 倍正好是 1920x1080，整数缩放，像素不糊。用 override.cfg 临时盖掉，录完删。
$cfg = "override.cfg"
if (Test-Path $cfg) { Write-Error "override.cfg 已存在，先看看是谁留下的"; exit 1 }
Set-Content -Path $cfg -Encoding ASCII -Value @"
[display]
window/size/window_width_override=1920
window/size/window_height_override=1080
"@
try {
	$env:REEL = $Part
	& $godot --path . res://tests/reel/reel.tscn --write-movie $avi --fixed-fps $Fps
}
finally {
	Remove-Item Env:REEL -ErrorAction SilentlyContinue
	Remove-Item $cfg -ErrorAction SilentlyContinue
}

if (-not (Test-Path $avi)) { Write-Error "没有录出 AVI"; exit 1 }
& $ffmpeg -y -loglevel error -i $avi -c:v libx264 -preset slow -crf 16 -pix_fmt yuv420p -c:a aac -b:a 192k -movflags +faststart $mp4
Write-Output "OK $mp4"
