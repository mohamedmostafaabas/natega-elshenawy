$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "Removing the old Excel file because the site now uses indexed server-side databases..." -ForegroundColor Cyan
Get-ChildItem -Path . -Filter *.xlsx -File -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem -Path . -Filter *.xls -File -ErrorAction SilentlyContinue | Remove-Item -Force

if (-not (Test-Path ".git")) {
    git init
    git branch -M main
    git remote add origin "https://github.com/mohamedmostafaabas/natega-elshenawy.git"
}

$origin = git remote get-url origin 2>$null
if ($LASTEXITCODE -ne 0) {
    git remote add origin "https://github.com/mohamedmostafaabas/natega-elshenawy.git"
} else {
    git remote set-url origin "https://github.com/mohamedmostafaabas/natega-elshenawy.git"
}

git add -A
$changes = git status --porcelain
if ($changes) {
    git commit -m "Use server-side indexed result search"
}
git push -u origin main

if (-not (Get-Command vercel -ErrorAction SilentlyContinue)) {
    npm install -g vercel@latest
}

vercel deploy --prod --yes
