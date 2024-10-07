# Specify the path to the file you want to check
$filePath = "" # Ex. "C:\Program Files\Autodesk\AutoCAD 2024\acad.exe"

# Check if the file exists
if (Test-Path $filePath) {
    # The file exists, so exit with code 0
    Write-Host 0
    exit 0
} else {
    # The file does not exist, so exit with a non-zero code
    Write-Host 1
    exit 1
}