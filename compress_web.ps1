# PowerShell script to compress Flutter Web build files for deployment
$sourcePath = "build/web"
$destinationPath = "hepb_analyzer_web.zip"

if (Test-Path $destinationPath) {
    Remove-Item $destinationPath -Force
}

if (Test-Path $sourcePath) {
    Compress-Archive -Path "$sourcePath\*" -DestinationPath $destinationPath -Force
    Write-Host "Successfully packaged build assets to $destinationPath"
} else {
    Write-Error "Error: build/web directory does not exist. Please run 'flutter build web' first."
}
