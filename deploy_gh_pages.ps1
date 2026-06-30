# PowerShell script to deploy Flutter Web build directly to GitHub Pages
$webPath = "build/web"

Write-Host "1. Building Flutter Web with base-href /hepb_analyzer/..." -ForegroundColor Cyan
flutter build web --base-href "/hepb_analyzer/"

if (-not (Test-Path $webPath)) {
    Write-Error "Error: Build folder $webPath not found. Aborting."
    exit 1
}

# Clean any existing git repo inside build/web
if (Test-Path "$webPath\.git") {
    Remove-Item -Recurse -Force "$webPath\.git"
}

Write-Host "2. Initializing git inside $webPath..." -ForegroundColor Cyan
Push-Location $webPath
git init
git checkout -b gh-pages

Write-Host "3. Adding files and committing..." -ForegroundColor Cyan
git add .
git commit -m "Deploy website to GitHub Pages"

Write-Host "4. Adding remote and pushing to gh-pages branch..." -ForegroundColor Cyan
git remote add origin https://github.com/saud-saud11/hepb_analyzer.git
git push -f origin gh-pages
Pop-Location

Write-Host "5. Enabling GitHub Pages on the repository..." -ForegroundColor Cyan
# Call GitHub API to enable GitHub Pages pointing to the gh-pages branch
gh api repos/saud-saud11/hepb_analyzer/pages -f source='{"branch":"gh-pages","path":"/"}' --silent

Write-Host "--------------------------------------------------------" -ForegroundColor Green
Write-Host "SUCCESS: Your site is deploying! It will be live in 1-2 minutes at:" -ForegroundColor Green
Write-Host "https://saud-saud11.github.io/hepb_analyzer/" -ForegroundColor Yellow
Write-Host "--------------------------------------------------------" -ForegroundColor Green
