# 一键发布：提交本地改动并推送到 GitHub Pages
#
# 用法：
#   .\deploy.ps1                      # 自动用时间当提交信息
#   .\deploy.ps1 -Message "改了什么"   # 自定义提交信息
#
# 发布路径（自动依次尝试）：
#   1. git 直连推送
#   2. 本机代理推送（如果 127.0.0.1:7890 在监听）
#   3. GitHub API 提交（前两条都失败时，走 api.github.com）
#
# 注意：走 API 时远端 commit 号与本地不同，但文件内容一致。
#       网络恢复后可执行 git fetch origin && git reset --hard origin/main 对齐历史。

param(
  [string]$Message = ""
)

# 不用 Stop：git 会把进度/换行警告写到 stderr，Stop 会误判为失败
$ErrorActionPreference = "Continue"
Set-Location $PSScriptRoot

$Repo   = "1221-peng/1221-peng.github.io"
$Proxy  = "http://127.0.0.1:7890"
$TmpDir = Join-Path $env:TEMP "dsh-deploy"

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

# ---------- 1. 提交 ----------
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

$commitMsg = (git log -1 --pretty=%s)
$baseArgs  = @("-c", "http.sslBackend=openssl", "-c", "credential.helper=!gh auth git-credential")

function Invoke-Push([string[]]$extra = @()) {
  $args = $baseArgs + $extra
  $out  = & git @args push origin main 2>&1
  return @{ code = $LASTEXITCODE; out = $out }
}

# ---------- 2. 直连 ----------
Write-Host "尝试直连推送…"
$r = Invoke-Push
if ($r.code -eq 0) {
  $r.out | ForEach-Object { Write-Host ("  " + $_) -ForegroundColor DarkGray }
  Write-Host "已推送（直连）。Pages 约 30–60 秒后完成构建：https://1221-peng.github.io/"
  exit 0
}

# ---------- 3. 代理 ----------
if (Test-Port) {
  Write-Host "直连失败，改走本机代理…"
  $r = Invoke-Push @("-c", "http.proxy=$Proxy", "-c", "https.proxy=$Proxy")
  if ($r.code -eq 0) {
    $r.out | ForEach-Object { Write-Host ("  " + $_) -ForegroundColor DarkGray }
    Write-Host "已推送（代理）。Pages 约 30–60 秒后完成构建：https://1221-peng.github.io/"
    exit 0
  }
  Write-Host "代理推送也失败。" -ForegroundColor Yellow
} else {
  Write-Host "未检测到本机代理（$Proxy）。" -ForegroundColor Yellow
}

# ---------- 4. GitHub API 兜底 ----------
Write-Host "改走 GitHub API 发布…"
New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null

$head     = (gh api "repos/$Repo/git/ref/heads/main" --jq ".object.sha").Trim()
$baseTree = (gh api "repos/$Repo/git/commits/$head" --jq ".tree.sha").Trim()

$files = @(git show --name-only --pretty=format: HEAD | Where-Object { $_ })
if (-not $files) { Write-Host "本次提交没有文件变更，无需发布。"; exit 0 }

$entries = @()
foreach ($rel in $files) {
  $path = Join-Path $PSScriptRoot $rel
  if (-not (Test-Path $path)) {
    $entries += @{ path = $rel; mode = "100644"; type = "blob"; sha = $null }
    Write-Host "  删除 $rel"
    continue
  }
  $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($path))
  $f   = Join-Path $TmpDir "blob.json"
  [IO.File]::WriteAllText($f, (@{ content = $b64; encoding = "base64" } | ConvertTo-Json -Compress), [Text.UTF8Encoding]::new($false))
  $sha = (gh api -X POST "repos/$Repo/git/blobs" --input $f --jq ".sha").Trim()
  $entries += @{ path = $rel; mode = "100644"; type = "blob"; sha = $sha }
  Write-Host "  上传 $rel"
}

$f = Join-Path $TmpDir "tree.json"
[IO.File]::WriteAllText($f, (@{ base_tree = $baseTree; tree = $entries } | ConvertTo-Json -Depth 6 -Compress), [Text.UTF8Encoding]::new($false))
$tree = (gh api -X POST "repos/$Repo/git/trees" --input $f --jq ".sha").Trim()

$f = Join-Path $TmpDir "commit.json"
[IO.File]::WriteAllText($f, (@{ message = $commitMsg; tree = $tree; parents = @($head) } | ConvertTo-Json -Depth 5 -Compress), [Text.UTF8Encoding]::new($false))
$newCommit = (gh api -X POST "repos/$Repo/git/commits" --input $f --jq ".sha").Trim()

$f = Join-Path $TmpDir "ref.json"
[IO.File]::WriteAllText($f, (@{ sha = $newCommit; force = $false } | ConvertTo-Json -Compress), [Text.UTF8Encoding]::new($false))
$null = gh api -X PATCH "repos/$Repo/git/refs/heads/main" --input $f --jq ".object.sha"

Write-Host "已通过 GitHub API 发布（远端 $($newCommit.Substring(0,7))）。Pages 约 30–60 秒后完成构建。"
Write-Host "提示：本地历史与远端不同（内容一致）；网络恢复后可执行：" -ForegroundColor DarkGray
Write-Host "  git fetch origin; git reset --hard origin/main" -ForegroundColor DarkGray
exit 0
