# Install shioaji CLI binary for Windows
# Usage: irm https://raw.githubusercontent.com/sinotrade/rshioaji/main/install.ps1 | iex
$ErrorActionPreference = "Stop"

$Repo = "sinotrade/rshioaji"
$BinaryName = "shioaji"
$InstallDir = if ($env:INSTALL_DIR) { $env:INSTALL_DIR } else { "$env:USERPROFILE\.local\bin" }

# Detect architecture
$Arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
switch ($Arch) {
    "X64"   { $ArchName = "x86_64" }
    "Arm64" { $ArchName = "aarch64" }
    default { Write-Error "Unsupported architecture: $Arch"; exit 1 }
}

# Get latest version
if (-not $env:VERSION) {
    $Release = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest"
    $Version = $Release.tag_name
} else {
    $Version = $env:VERSION
}

Write-Host "Installing $BinaryName $Version (Windows $ArchName)..."

# Download
$Archive = "$BinaryName-$Version-Windows-$ArchName.zip"
$Url = "https://github.com/$Repo/releases/download/$Version/$Archive"
$TmpDir = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path $_ }

Write-Host "Downloading $Url..."
Invoke-WebRequest -Uri $Url -OutFile "$TmpDir\$Archive"

# Extract
Expand-Archive -Path "$TmpDir\$Archive" -DestinationPath $TmpDir -Force

# Install
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}
Move-Item -Path "$TmpDir\$BinaryName.exe" -Destination "$InstallDir\$BinaryName.exe" -Force

Write-Host "Installed $BinaryName to $InstallDir\$BinaryName.exe"

# Check PATH
if ($env:PATH -notlike "*$InstallDir*") {
    Write-Host ""
    Write-Host "Add $InstallDir to your PATH:"
    Write-Host "  `$env:PATH = `"$InstallDir;`$env:PATH`""
    Write-Host ""
    Write-Host "To make it permanent:"
    Write-Host "  [Environment]::SetEnvironmentVariable('PATH', `"$InstallDir;`$([Environment]::GetEnvironmentVariable('PATH', 'User'))`", 'User')"
}

# Cleanup
Remove-Item -Recurse -Force $TmpDir

Write-Host "Run '$BinaryName --help' to get started."
