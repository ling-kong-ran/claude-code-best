$ErrorActionPreference = 'Stop'

$repo = 'E:\openclaw\claw_workspace\claude-code-best'
$branch = 'dev'
$upstreamBranch = 'upstream/main'
$tempDir = 'E:\tmp'

New-Item -ItemType Directory -Force $tempDir | Out-Null
$env:TEMP = $tempDir
$env:TMP = $tempDir

Set-Location $repo

function Fail($message) {
  Write-Output "RESULT=FAIL"
  Write-Output "MESSAGE=$message"
  exit 1
}

function Success($message) {
  Write-Output "RESULT=OK"
  Write-Output "MESSAGE=$message"
  exit 0
}

function ResetToOriginDev() {
  $originDev = git rev-parse origin/$branch
  if ($LASTEXITCODE -ne 0) { Fail 'failed to resolve origin/dev' }
  git reset --hard $originDev.Trim() | Out-Null
  if ($LASTEXITCODE -ne 0) { Fail 'failed to reset dev to origin/dev' }
}

$gitStatus = git status --porcelain
if ($LASTEXITCODE -ne 0) { Fail 'git status failed' }
if ($gitStatus) { Fail 'working tree is not clean' }

$currentBranch = git rev-parse --abbrev-ref HEAD
if ($LASTEXITCODE -ne 0) { Fail 'failed to detect current branch' }
if ($currentBranch.Trim() -ne $branch) {
  git checkout $branch
  if ($LASTEXITCODE -ne 0) { Fail 'failed to checkout dev branch' }
}

git fetch origin
if ($LASTEXITCODE -ne 0) { Fail 'git fetch origin failed' }

git fetch upstream
if ($LASTEXITCODE -ne 0) { Fail 'git fetch upstream failed' }

ResetToOriginDev

$behindAheadRaw = git rev-list --left-right --count HEAD...$upstreamBranch
if ($LASTEXITCODE -ne 0) { Fail 'failed to compare dev with upstream/main' }
$behindAhead = ($behindAheadRaw | Out-String).Trim()
$parts = [regex]::Split($behindAhead, '\s+') | Where-Object { $_ -ne '' }
if ($parts.Count -lt 2) { Fail "unexpected rev-list output: $behindAhead" }
$left = [int]$parts[0]
$right = [int]$parts[1]

if ($right -eq 0) {
  Success 'No new upstream commits to merge into dev.'
}

git merge --no-edit $upstreamBranch
if ($LASTEXITCODE -ne 0) {
  git merge --abort | Out-Null
  ResetToOriginDev
  Fail 'merge conflict or merge failure while merging upstream/main into dev'
}

bun run dev --help | Out-Null
if ($LASTEXITCODE -ne 0) {
  ResetToOriginDev
  Fail 'bun run dev --help failed after merge; reverted local dev back to origin/dev'
}

bun run build | Out-Null
if ($LASTEXITCODE -ne 0) {
  ResetToOriginDev
  Fail 'bun run build failed after merge; reverted local dev back to origin/dev'
}

$pushOutput = git push origin $branch 2>&1
if ($LASTEXITCODE -ne 0) {
  ResetToOriginDev
  Fail "git push failed: $pushOutput"
}

$newHead = git rev-parse --short HEAD
if ($LASTEXITCODE -ne 0) { Fail 'failed to resolve final HEAD' }

Success "Merged upstream/main into dev, tests passed, and pushed origin/dev at $($newHead.Trim())."
