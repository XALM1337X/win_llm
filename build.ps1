# build.ps1

# Path to MSVC compiler
$cl = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.40.33807\bin\Hostx64\x64\cl.exe"

# Get the directory where this script is located
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Set up project structure relative to script location
$srcDir = Join-Path $scriptDir "src"
$binDir = Join-Path $scriptDir "bin"
$includeDir = Join-Path $srcDir "include"
$libDir = Join-Path $srcDir "lib"
$objDir = Join-Path $srcDir "obj"
$cppDir = Join-Path $srcDir "cpp"

# Ensure bin and obj directories exist
if (!(Test-Path $binDir)) { New-Item -ItemType Directory -Path $binDir | Out-Null }
if (!(Test-Path $objDir)) { New-Item -ItemType Directory -Path $objDir | Out-Null }
if (!(Test-Path $cppDir)) { New-Item -ItemType Directory -Path $cppDir | Out-Null }
if (!(Test-Path $includeDir)) { New-Item -ItemType Directory -Path $includeDir | Out-Null }
if (!(Test-Path $libDir)) { New-Item -ItemType Directory -Path $libDir | Out-Null }


# Find all .cpp files in cpp directory
$cppFiles = Get-ChildItem -Path $cppDir -Filter *.cpp

# Compile each .cpp file to .obj, placing .obj in obj directory
$ErrorActionPreference = "Stop"
$includeArgs = @(
    "/I""$includeDir""",
    "/I""C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.40.33807\include""",
    "/I""C:\Program Files (x86)\Windows Kits\10\Include\10.0.22621.0\ucrt""",
    "/I""C:\Program Files (x86)\Windows Kits\10\Include\10.0.22621.0\um""",
    "/I""C:\Program Files (x86)\Windows Kits\10\Include\10.0.22621.0\shared""",
    "/I""C:\Program Files (x86)\Windows Kits\10\Include\10.0.22621.0\winrt""",
    "/I""C:\Program Files (x86)\Windows Kits\10\Include\10.0.22621.0\cppwinrt"""
)

foreach ($cpp in $cppFiles) {
    $objFile = Join-Path $objDir ([System.IO.Path]::GetFileNameWithoutExtension($cpp.Name) + ".obj")
    $clArgs = @("/nologo", "/c", "/EHsc") + $includeArgs + @("`"$($cpp.FullName)`"","/Fo:`"$objFile`"")

    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = $cl
    $processInfo.Arguments = $clArgs -join " "
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo
    $process.Start() | Out-Null
    $stdOut = $process.StandardOutput.ReadToEnd()
    $stdErr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($process.ExitCode -ne 0) {
        echo "Compilation failed for $($cpp.Name):"
        if ($stdErr) { echo $stdErr }
        if ($stdOut) { echo $stdOut }
        exit $process.ExitCode
    }
}

# Gather all .obj files for linking
$objFiles = Get-ChildItem -Path $objDir -Filter *.obj | ForEach-Object { "`"$($_.FullName)`"" }

# Output binary path
$projectName = Split-Path -Leaf $scriptDir
$outBinary = Join-Path $binDir "$projectName.exe"

# Link all object files
$linkArgs = @("/nologo", "/EHsc") + $includeArgs + $objFiles + @(
    "/link",
    "/OUT:`"$outBinary`"",
    "/LIBPATH:""C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.40.33807\lib\x64""",
    "/LIBPATH:""C:\Program Files (x86)\Windows Kits\10\Lib\10.0.22621.0\ucrt\x64""",
    "/LIBPATH:""C:\Program Files (x86)\Windows Kits\10\Lib\10.0.22621.0\um\x64""",
    "/LIBPATH:`"$libDir`""
)

$processInfo = New-Object System.Diagnostics.ProcessStartInfo
$processInfo.FileName = $cl
$processInfo.Arguments = $linkArgs -join " "
$processInfo.RedirectStandardOutput = $true
$processInfo.RedirectStandardError = $true
$processInfo.UseShellExecute = $false
$processInfo.CreateNoWindow = $true

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $processInfo
$process.Start() | Out-Null
$stdOut = $process.StandardOutput.ReadToEnd()
$stdErr = $process.StandardError.ReadToEnd()
$process.WaitForExit()

if ($process.ExitCode -ne 0) {
    echo "Linking failed:"
    if ($stdErr) { echo $stdErr }
    if ($stdOut) { echo $stdOut }
    exit $process.ExitCode
}

# Clean up .obj files after successful build
Get-ChildItem -Path $objDir -Filter *.obj | Remove-Item

echo "Build succeeded. Output: $outBinary"