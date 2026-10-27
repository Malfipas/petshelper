<#
    打一个能拷到别的 Windows 机器上直接跑的包。

    用法（在 app/ 目录下）：
        powershell -ExecutionPolicy Bypass -File tool/package_windows.ps1
        powershell -ExecutionPolicy Bypass -File tool/package_windows.ps1 -SkipBuild
        powershell -ExecutionPolicy Bypass -File tool/package_windows.ps1 -Inno

    产出：
        dist/桌宠日常助手-<版本>/            解开就能用的那堆文件
        dist/桌宠日常助手-<版本>-win64.zip   发人用的
        dist/桌宠日常助手-<版本>-setup.exe   只有装了 Inno Setup 且带 -Inno 才有

    为什么不直接压 build 目录：build 里还有 CMake 缓存和中间产物，几百兆无关文件，
    而且下次构建会覆盖、删除，不该当成交付物。
#>
[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [switch]$Inno
)

$ErrorActionPreference = 'Stop'
$appDir = Split-Path -Parent $PSScriptRoot
$repoDir = Split-Path -Parent $appDir
$distDir = Join-Path $repoDir 'dist'

# 版本号只有 pubspec.yaml 一处，别在脚本里再抄一遍
$pubspec = Get-Content (Join-Path $appDir 'pubspec.yaml') -TotalCount 40
$versionLine = $pubspec | Where-Object { $_ -match '^version:\s*(\S+)' } | Select-Object -First 1
if (-not $versionLine) { throw 'pubspec.yaml 里没找到 version' }
$version = ($versionLine -replace '^version:\s*', '').Split('+')[0]
$name = "桌宠日常助手-$version"
$outDir = Join-Path $distDir $name
$releaseDir = Join-Path $appDir 'build\windows\x64\runner\Release'

Write-Host "版本 $version"

if (-not $SkipBuild) {
    Write-Host '构建 release…'
    Push-Location $appDir
    try {
        & flutter build windows --release
        if ($LASTEXITCODE -ne 0) { throw "flutter build 失败，退出码 $LASTEXITCODE" }
    }
    finally { Pop-Location }
}

if (-not (Test-Path $releaseDir)) { throw "没有 release 产物：$releaseDir" }

if (Test-Path $outDir) { Remove-Item $outDir -Recurse -Force }
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
Copy-Item (Join-Path $releaseDir '*') $outDir -Recurse -Force

# 拿到包的人不需要知道仓库结构，这张纸是给他们的
$readme = @"
AI桌宠日常助手 $version

怎么开
  双击 ai_pet_assistant.exe。第一次打开没有窗口铺满屏幕是正常的：
  桌宠会出现在屏幕右缘，鼠标移上去出现小面板，面板里点「展开」进主界面。

用 AI 之前
  主界面 → 设置 → 填 DeepSeek（或任何 OpenAI 兼容服务）的 API key → 保存。
  不填也能用，只是拆解、问一问、想法归类、日总结这四处不出结果。

怎么退出
  右键托盘图标 → 退出。直接关主界面只是收起，进程还在，这是故意的。
  想让下次开机自己出现，在设置页把「开机自启」打开。

几点说明
  - 数据库在 %USERPROFILE%\Documents\app.db，key 走系统安全存储，不进数据库、不进日志。
  - 想彻底清干净：退出程序，删掉那个 app.db，再删 %APPDATA%\com.aipet\ai_pet_assistant\ 下的 api_key.bin。
  - 这个目录整个拷走就能在另一台 Windows 10/11 x64 上跑，不需要装 Flutter。
"@
$readmePath = Join-Path $outDir '运行说明.txt'
# 记事本读 UTF-8 需要 BOM，否则中文是乱码
[IO.File]::WriteAllText($readmePath, $readme, (New-Object System.Text.UTF8Encoding($true)))

$zipPath = Join-Path $distDir "$name-win64.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Write-Host '压缩…'
Compress-Archive -Path $outDir -DestinationPath $zipPath -CompressionLevel Optimal

$size = (Get-Item $zipPath).Length / 1MB
Write-Host ("好了：{0}（{1:N1} MB）" -f $zipPath, $size)

if ($Inno) {
    $iscc = Get-Command iscc -ErrorAction SilentlyContinue
    if (-not $iscc) {
        Write-Warning '没找到 iscc，跳过安装包。装了 Inno Setup 6 再带 -Inno 跑一次，或者直接发 zip。'
    }
    else {
        $iss = Join-Path $appDir 'installer\ai_pet_assistant.iss'
        Write-Host '打安装包…'
        & $iscc.Source "/DAppVersion=$version" "/DSourceDir=$outDir" "/DOutputDir=$distDir" $iss
        if ($LASTEXITCODE -ne 0) { throw "iscc 失败，退出码 $LASTEXITCODE" }
        Write-Host "安装包在 $distDir"
    }
}
