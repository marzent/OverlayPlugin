param (
    [switch]$ci = $false
)

try {
    # This assumes Visual Studio 2022 is installed in C:. You might have to change this depending on your system.
    $DEFAULT_VS_PATH = "C:\Program Files\Microsoft Visual Studio\2022\Community"

    $DEFAULT_VSWHERE_PATH = "${Env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if ( -not (Test-Path "$DEFAULT_VSWHERE_PATH")) {
        Write-Output "Unable to find vswhere.exe, defauling to $DEFAULT_VS_PATH value in build.ps1."
        if ( -not (Test-Path "$DEFAULT_VS_PATH")) {
            Write-Output "Error: DEFAULT_VS_PATH isn't set correctly! Update the variable in build.ps1 for your system."
            exit 1
        }
        $VS_PATH = $DEFAULT_VS_PATH
    } else {
        $VS_PATH = & "$DEFAULT_VSWHERE_PATH" -latest -property installationPath
    }

    if ( -not (Test-Path "Thirdparty\ACT\Advanced Combat Tracker.exe" )) {
        Write-Output 'Error: Please run tools\fetch_deps.py'
        exit 1
    }


    if ( -not (Test-Path "Thirdparty\FFXIV_ACT_Plugin\SDK\FFXIV_ACT_Plugin.Common.dll" )) {
        Write-Output 'Error: Please run tools\fetch_deps.py'
        exit 1
    }

    $ENV:PATH = "$VS_PATH\MSBuild\Current\Bin;${ENV:PATH}";
    if (Test-Path "C:\Program Files\7-Zip\7z.exe") {
        $ENV:PATH = "C:\Program Files\7-Zip;${ENV:PATH}";
    }

    if ( -not (Test-Path .\OverlayPlugin.Updater\Resources\libcurl.dll)) {
        Write-Output "==> Building cURL..."

        mkdir .\OverlayPlugin.Updater\Resources
        Set-Location Thirdparty\curl\winbuild

        Write-Output "@call `"$VS_PATH\VC\Auxiliary\Build\vcvarsall.bat`" amd64"           | Out-File -Encoding ascii tmp_build.bat
        Write-Output "nmake /f Makefile.vc mode=dll VC=16 GEN_PDB=no DEBUG=no MACHINE=x64" | Out-File -Encoding ascii -Append tmp_build.bat
        Write-Output "@call `"$VS_PATH\VC\Auxiliary\Build\vcvarsall.bat`" x86"             | Out-File -Encoding ascii -Append tmp_build.bat
        Write-Output "nmake /f Makefile.vc mode=dll VC=16 GEN_PDB=no DEBUG=no MACHINE=x86" | Out-File -Encoding ascii -Append tmp_build.bat

        cmd "/c" "tmp_build.bat"
        Start-Sleep 3
        Remove-Item tmp_build.bat

        Set-Location ..\builds
        Copy-Item .\libcurl-vc16-x64-release-dll-ipv6-sspi-winssl\bin\libcurl.dll ..\..\..\OverlayPlugin.Updater\Resources\libcurl-x64.dll
        Copy-Item .\libcurl-vc16-x86-release-dll-ipv6-sspi-winssl\bin\libcurl.dll ..\..\..\OverlayPlugin.Updater\Resources\libcurl.dll

        Set-Location ..\..\..
    }

    if ($ci) {
        Write-Output "==> Continuous integration flag set. Building Debug..."
        dotnet publish -c debug  
    }

    Write-Output "==> Building..."

    dotnet publish -c release
    
    if (-not $?) { exit 1 }

    Write-Output "==> Building archive..."

    Set-Location out\Release\net48

    if (Test-Path ..\OverlayPlugin) { Remove-Item ..\OverlayPlugin -Recurse}
    New-Item -Path ".." -Name "OverlayPlugin" -ItemType "directory"

    Copy-Item -Path "publish\*" -Destination "..\OverlayPlugin\" -Recurse

    Set-Location ..\OverlayPlugin
    Remove-Item CefSharp -Recurse
    Remove-Item *.pdb
    Remove-Item *.dll.config
    
    [xml]$csprojcontents = Get-Content -Path "$PWD\..\..\..\OverlayPlugin\OverlayPlugin.csproj";
    $version = $csprojcontents.Project.PropertyGroup.Version;
    $archive = "..\OverlayPlugin-$version.7z"

    if (Test-Path $archive) { Remove-Item $archive }
    7z a ..\$archive .
    Set-Location ..

    $archive = "..\OverlayPlugin-$version.zip"

    if (Test-Path $archive) { Remove-Item $archive }
    7z a $archive OverlayPlugin
} catch {
    Write-Error $Error[0]
}
