# 一键发布：提交本地改动并推送到 GitHub Pages
#
# 用法：
#   .\deploy.ps1                      # 自动用时间当提交信息
#   .\deploy.ps1 -Message "改了什么"   # 自定义提交信息
#
# 说明：
#   1. 提交前会检查是否有改动，没改动就只做推送检查。
#   2. github.com 直连经常被阻断，脚本会自动检测本机代理（127.0.0.1:7890）；
#      代理开着就走代理，没开就直连（直连失败会提示）。
#   3. 推送后 GitHub Pages 约 30–60 秒自动构建。

param(
  [string]$Message = ""
)

# 注意：不用 Stop —— git 会把进度/换行警告写到 stderr，Stop 会误判为失败
$ErrorActionPreference = "Continue"
Set-Location $PSScriptRoot

function Test-Port([string]$Address = "127.0.0.1", [int]$Port = 7890, [int]$TimeoutMs = 600) {
  $client = New-Object System.Net.Sockets.TcpClient
  try {
    $iar = $client.BeginConnect($Address, $Port, $null, $null)
    if (-not $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) { return $false }
    $client.EndConnect($iar)
    return $true
  } catch {
    return $false
  } finally {
    $client.Dispose()
  }
}

# 1. 提交
$changes = git status --porcelain 2>$null
if ($changes) {
  if (-not $Message) { $Message = "更新内容 " + (Get-Date -Format "yyyy-MM-dd HH:mm") }
  $null = git add -A 2>&1
  $null = git -c user.name="彭佳艺" -c user.email="pengjiayi2929@163.com" commit -q -m $Message 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Host "提交失败，已中止。" -ForegroundColor Yellow
    exit 1
  }
  Write-Host "已提交：$Message"
} else {
  Write-Host "没有文件改动。"
}

# 2. 代理探测
$proxyArgs = @()
if (Test-Port) {
  $proxyArgs = @("-c", "http.proxy=http://127.0.0.1:7890", "-c", "https.proxy=http://127.0.0.1:7890")
  Write-Host "检测到本机代理，走代理推送。"
} else {
  Write-Host "未检测到代理，尝试直连。"
}

$gitArgs = @("-c", "http.sslBackend=openssl", "-c", "credential.helper=!gh auth git-credential") + $proxyArgs

# 3. 推送
$pushOut  = & git @gitArgs push origin main 2>&1
$pushCode = $LASTEXITCODE
$pushOut | ForEach-Object { Write-Host ("  " + $_) -ForegroundColor DarkGray }

if ($pushCode -ne 0) {
  Write-Host ""
  Write-Host "推送失败。常见原因：" -ForegroundColor Yellow
  Write-Host "  · github.com 被阻断，且本机代理未开启（默认检测 127.0.0.1:7890）"
  Write-Host "  · GitHub 登录态失效：先运行 gh auth status 检查"
  exit 1
}

Write-Host "已推送。GitHub Pages 约 30–60 秒后完成构建：https://1221-peng.github.io/"
exit 0
