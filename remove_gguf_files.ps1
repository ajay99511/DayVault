# GGUF Code Removal Script
# This script removes all GGUF-related code from DayVault
# Run this script manually if files weren't deleted automatically

Write-Host "DayVault GGUF Code Removal" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan
Write-Host ""

$filesToRemove = @(
    "lib\services\llama_runtime_service.dart",
    "lib\services\ai_runtime_policy_service.dart",
    "lib\services\ai_model_registry_service.dart",
    "GGUF_REFERENCE.md"
)

Write-Host "Files to remove:" -ForegroundColor Yellow
foreach ($file in $filesToRemove) {
    Write-Host "  - $file"
}
Write-Host ""

foreach ($file in $filesToRemove) {
    if (Test-Path $file) {
        Remove-Item $file -Force
        Write-Host "[REMOVED] $file" -ForegroundColor Green
    } else {
        Write-Host "[NOT FOUND] $file" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "GGUF code removal complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Update pubspec.yaml to remove GGUF dependencies"
Write-Host "2. Clean RAG service of GGUF references"
Write-Host "3. Update AndroidManifest.xml to remove OpenCL libraries"
Write-Host "4. Run: flutter pub get"
Write-Host "5. Run: flutter analyze"
