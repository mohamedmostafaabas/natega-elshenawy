$ErrorActionPreference = "Stop"

$ProjectPath = Join-Path $HOME "Downloads\natega"
$RepoName = "natega-elshenawy"
$ProjectName = "natega-elshenawy"

function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

function Assert-LastExitCode([string]$Step) {
    if ($LASTEXITCODE -ne 0) {
        throw "فشلت الخطوة: $Step (Exit code: $LASTEXITCODE)"
    }
}

Write-Host "`n=== natega-elshenawy: GitHub + Vercel deployment ===" -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $ProjectPath)) {
    throw "المجلد غير موجود: $ProjectPath"
}

Set-Location -LiteralPath $ProjectPath

$RequiredFiles = @(
    "index.html",
    "نتيجة ثانوية عامة نظام حديث.xlsx"
)
foreach ($File in $RequiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $ProjectPath $File))) {
        throw "الملف المطلوب غير موجود: $File"
    }
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "Windows Package Manager (winget) غير موجود. ثبّت App Installer من Microsoft Store ثم أعد تشغيل الأمر."
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Git..." -ForegroundColor Yellow
    winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
    Assert-LastExitCode "تثبيت Git"
    Refresh-Path
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "Installing GitHub CLI..." -ForegroundColor Yellow
    winget install --id GitHub.cli -e --source winget --accept-package-agreements --accept-source-agreements
    Assert-LastExitCode "تثبيت GitHub CLI"
    Refresh-Path
}

if (-not (Get-Command node -ErrorAction SilentlyContinue) -or -not (Get-Command npx -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Node.js LTS..." -ForegroundColor Yellow
    winget install --id OpenJS.NodeJS.LTS -e --source winget --accept-package-agreements --accept-source-agreements
    Assert-LastExitCode "تثبيت Node.js"
    Refresh-Path
}

Write-Host "`n[1/5] GitHub authentication" -ForegroundColor Cyan
gh auth status *> $null
if ($LASTEXITCODE -ne 0) {
    gh auth login --web --git-protocol https
    Assert-LastExitCode "تسجيل الدخول إلى GitHub"
}

$GitHubUser = (gh api user --jq .login).Trim()
Assert-LastExitCode "قراءة حساب GitHub"
$FullRepo = "$GitHubUser/$RepoName"
$RemoteUrl = "https://github.com/$FullRepo.git"

Write-Host "`n[2/5] Preparing local Git repository" -ForegroundColor Cyan
if (-not (Test-Path -LiteralPath ".git")) {
    git init
    Assert-LastExitCode "git init"
}

git config user.name $GitHubUser
if (-not (git config user.email)) {
    git config user.email "$GitHubUser@users.noreply.github.com"
}

git add --all
Assert-LastExitCode "git add"

git diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
    git commit -m "Launch natega-elshenawy result portal"
    Assert-LastExitCode "git commit"
} else {
    Write-Host "No new local changes to commit." -ForegroundColor DarkGray
}

git branch -M main
Assert-LastExitCode "تسمية الفرع main"

Write-Host "`n[3/5] Creating/updating GitHub repository" -ForegroundColor Cyan
gh repo view $FullRepo --json url *> $null
$RepoExists = ($LASTEXITCODE -eq 0)

if (-not $RepoExists) {
    gh repo create $FullRepo --public --description "بوابة البحث في نتيجة الثانوية العامة بالاسم أو رقم الجلوس" --source . --remote origin
    Assert-LastExitCode "إنشاء مستودع GitHub"
} else {
    git remote get-url origin *> $null
    if ($LASTEXITCODE -eq 0) {
        git remote set-url origin $RemoteUrl
    } else {
        git remote add origin $RemoteUrl
    }
    Assert-LastExitCode "ضبط remote origin"
}

git push -u origin main
Assert-LastExitCode "رفع المشروع إلى GitHub"

Write-Host "`n[4/5] Vercel authentication and project linking" -ForegroundColor Cyan
npx --yes vercel@latest whoami *> $null
if ($LASTEXITCODE -ne 0) {
    npx --yes vercel@latest login --github
    Assert-LastExitCode "تسجيل الدخول إلى Vercel"
}

npx --yes vercel@latest link --yes --project $ProjectName
if ($LASTEXITCODE -ne 0) {
    Write-Host "Project linking by name failed; creating it during deployment..." -ForegroundColor Yellow
    $DeployUrl = (npx --yes vercel@latest deploy --prod --yes --name $ProjectName --archive=tgz | Select-Object -Last 1).Trim()
    Assert-LastExitCode "إنشاء مشروع Vercel ونشره"
} else {
    npx --yes vercel@latest git connect --yes
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Vercel Git connection was not completed automatically; the direct deployment will still continue." -ForegroundColor Yellow
    }

    Write-Host "`n[5/5] Production deployment" -ForegroundColor Cyan
    $DeployUrl = (npx --yes vercel@latest deploy --prod --yes --archive=tgz | Select-Object -Last 1).Trim()
    Assert-LastExitCode "النشر على Vercel"
}

Write-Host "`nDeployment completed successfully." -ForegroundColor Green
Write-Host "GitHub: https://github.com/$FullRepo" -ForegroundColor Green
Write-Host "Vercel: $DeployUrl" -ForegroundColor Green

Start-Process $DeployUrl
