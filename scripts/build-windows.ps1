$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RootDir = Resolve-Path (Join-Path $PSScriptRoot "..")
$WindowsDir = Join-Path $RootDir "apps/windows"

Push-Location $WindowsDir
try {
    dotnet restore "src/BeamDrop.Windows.App/BeamDrop.Windows.App.csproj"
    dotnet build "src/BeamDrop.Windows.App/BeamDrop.Windows.App.csproj" --no-restore
    dotnet restore "Tests/BeamDrop.Windows.Tests/BeamDrop.Windows.Tests.csproj"
    dotnet build "Tests/BeamDrop.Windows.Tests/BeamDrop.Windows.Tests.csproj" --no-restore
    dotnet run --project "Tests/BeamDrop.Windows.Tests/BeamDrop.Windows.Tests.csproj" --no-build
    dotnet restore "Tests/Tests.csproj"
    dotnet build "Tests/Tests.csproj" --no-restore
    dotnet run --project "Tests/Tests.csproj" --no-build
}
finally {
    Pop-Location
}
