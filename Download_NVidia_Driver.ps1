<#
	.SYNOPSIS
	Check for the latest NVIDIA driver version, and if it's newer than the installed one, download and extract it

	.NOTES
	https://docs.nvidia.com/sdk-manager/sdkm-command-line-install/index.html
#>

#Requires -RunAsAdministrator
#Requires -Version 5.1

Clear-Host

if ($PSVersionTable.PSVersion.Major -eq 5)
{
	# Progress bar can significantly impact cmdlet performance
	# https://github.com/PowerShell/PowerShell/issues/2138
	$Script:ProgressPreference = "SilentlyContinue"

	# Enable TLS 1.2 keeping already enabled protocols
	[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
}

# Checking Windows version
if ([Environment]::OSVersion.Version.Major -lt 10)
{
	Write-Verbose -Message "Your Windows is unsupported. Upgrade to Windows 10 or higher" -Verbose
	pause
	exit
}

# Checking Windows bitness
if (-not [Environment]::Is64BitOperatingSystem)
{
	Write-Verbose -Message "The script supports X86-64 architecture based CPU only" -Verbose
	pause
	exit
}

# Get active NVIDIA video card. Query once and reuse for both driver version and model name

# The NVIDIA System Management Interface (nvidia-smi) is a command line utility, based on top of the NVIDIA Management Library (NVML)
[System.Version]$CurrentDriverVersion = & "$env:SystemRoot\System32\nvidia-smi.exe" --query-gpu=driver_version --format=csv,noheader
$GPU = Get-CimInstance -ClassName Win32_VideoController | Where-Object -FilterScript {($_.Name -like "NVIDIA *") -and ($_.Status -eq "OK")} | Select-Object -First 1
if (-not ($CurrentDriverVersion -and $GPU))
{
	Write-Verbose -Message "No active NVIDIA video card detected" -Verbose
	pause
	exit
}
else
{
	Write-Verbose -Message "No NVdia card detected." -Verbose
	pause
	exit
}

Write-Verbose -Message "Video card: $($GPU.Name)" -Verbose
Write-Verbose -Message "Current version: $CurrentDriverVersion" -Verbose
Write-Information -MessageData "" -InformationAction Continue

# Checking latest driver version from Nvidia website
try
{
	$Parameters = @{
		Uri             = "https://www.nvidia.com/Download/API/lookupValueSearch.aspx?TypeID=3"
		UseBasicParsing = $true
		Verbose         = $true
	}
	[xml]$Content = Invoke-RestMethod @Parameters
}
catch
{
	Write-Warning -Message "Cannot establish connection to $($Parameters.Uri)"
	pause
	exit
}

# Exact match by full name ("NVIDIA RTX A4000") or by name without vendor ("GeForce RTX 4070")
$CardModelName = $GPU.Name.Substring(7)
$LookupValue = $Content.LookupValueSearch.LookupValues.LookupValue | Where-Object -FilterScript {($_.Name -eq $GPU.Name) -or ($_.Name -eq $CardModelName)} | Select-Object -First 1
if (-not $LookupValue)
{
	Write-Warning -Message "$($GPU.Name) not found in NVIDIA database"
	pause
	exit
}

# osID=57 — Windows x64/Windows 11
# languageCode=1033 — English language
# dch=1 — DCH drivers
# https://nvidia.custhelp.com/app/answers/detail/a_id/4777/~/nvidia-dch%2Fstandard-display-drivers-for-windows-10-faq
# upCRD=0 — Game Ready Driver
try
{
	$Parameters = @{
		Uri             = "https://gfwsl.geforce.com/services_toolkit/services/com/nvidia/services/AjaxDriverService.php?func=DriverManualLookup&psid=$($LookupValue.ParentID)&pfid=$($LookupValue.Value)&osID=57&languageCode=1033&beta=null&isWHQL=1&dltype=-1&dch=1&upCRD=0"
		UseBasicParsing = $true
		Verbose         = $true
	}
	$Data = Invoke-RestMethod @Parameters
}
catch
{
	Write-Warning -Message "Cannot establish connection to $($Parameters.Uri)"
	pause
	exit
}

$DownloadInfo = @($Data.IDS)[0].downloadInfo
if (-not $DownloadInfo.Version)
{
	Write-Warning -Message "Something went wrong"
	pause
	exit
}

[System.Version]$LatestVersion = $DownloadInfo.Version
Write-Verbose -Message "Latest version: $LatestVersion" -Verbose
Write-Information -MessageData "" -InformationAction Continue

# Comparing installed driver version to latest driver version from Nvidia
if ($LatestVersion -le $CurrentDriverVersion)
{
	Write-Verbose -Message "The installed NVIDIA driver is up to date" -Verbose
	pause
	exit
}

$DownloadsFolder = Get-ItemPropertyValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "{374DE290-123F-4565-9164-39C4925E467B}"

# Take the file name from the URL: desktop and notebook packages are named differently
$Installer = Join-Path -Path $DownloadsFolder -ChildPath $DownloadInfo.DownloadURL.Split("/")[-1]

if (-not (Test-Path -Path $Installer))
{
	Write-Verbose -Message "Downloading $($DownloadInfo.DownloadURL)" -Verbose

	try
	{
		$Parameters = @{
			Uri             = $DownloadInfo.DownloadURL
			OutFile         = $Installer
			UseBasicParsing = $true
			Verbose         = $true
		}
		Invoke-WebRequest @Parameters
	}
	catch
	{
		# Do not leave a partially downloaded file, otherwise the next run skips downloading
		Remove-Item -Path $Installer -Force -ErrorAction Ignore

		Write-Warning -Message "Cannot establish connection to $($DownloadInfo.DownloadURL)"
		pause
		exit
	}
}

# Get the latest 7-Zip download URL
# https://github.com/ip7z/7zip
try
{
	$Parameters = @{
		Uri             = "https://api.github.com/repos/ip7z/7zip/releases/latest"
		UseBasicParsing = $true
		Verbose         = $true
	}
	$URL = ((Invoke-RestMethod @Parameters).assets | Where-Object -FilterScript {$_.name -match "x64.msi"}).browser_download_url
}
catch [System.Net.WebException]
{
	Write-Warning -Message "Cannot establish connection to https://api.github.com/repos/ip7z/7zip/releases/latest"
	pause
	exit
}

try
{
	$Parameters = @{
		Uri             = $URL
		OutFile         = "$DownloadsFolder\7Zip.msi"
		UseBasicParsing = $true
		Verbose         = $true
	}
	Invoke-WebRequest @Parameters
}
catch [System.Net.WebException]
{
	Write-Warning -Message "Cannot establish connection to $URL"
	exit
	pause
}

# Expand 7-Zip
$Arguments = @(
	"/a `"$DownloadsFolder\7Zip.msi`""
	"TARGETDIR=`"$DownloadsFolder\7zip`""
	"/qn"
)
Start-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList $Arguments -Wait

Remove-Item -Path "$DownloadsFolder\7Zip.msi" -Force

# Extracting installer
# Based on 7-zip.chm
$Arguments = @(
	# Extracts files from an archive with their full paths in the current directory, or in an output directory if specified
	"x",
	# standard output messages. disable stream
	"-bso0",
	# progress information. redirect to stdout stream
	"-bsp1",
	# error messages. redirect to stdout stream
	"-bse1",
	# Overwrite All existing files without prompt
	"-aoa",
	# What to extract
	"`"$Installer`"",
	# Extract these files and folders
	"Display.Driver",
	"HDAudio",
	"NVI2",
	"NVApp",
	"NVApp.MessageBus",
	"NVCpl",
	"PhysX",
	"EULA.txt",
	"ListDevices.txt",
	"setup.cfg",
	"setup.exe",
	# Specifies a destination directory where files are to be extracted
	"-o`"$DownloadsFolder\NVidia`""
)
$Parameters = @{
	FilePath     = "$DownloadsFolder\7zip\Files\7-Zip\7z.exe"
	ArgumentList = $Arguments
	NoNewWindow  = $true
	Wait         = $true
	PassThru     = $true
}
Start-Process @Parameters

<# Remove unnecessary dependencies from setup.cfg
[xml]$setup = Get-Content -Path "$DownloadsFolder\NVidia\setup.cfg" -Encoding UTF8 -Force
($setup.setup.manifest.file | Where-Object -FilterScript {@("`${{EulaHtmlFile}}", "`${{FunctionalConsentFile}}", "`${{PrivacyPolicyFile}}") -contains $_.name }) | ForEach-Object {
	$_.ParentNode.RemoveChild($_)
}
$setup.Save("$DownloadsFolder\NVidia\setup.cfg")
#>

Remove-Item -Path $Installer -Force

Invoke-Item -Path "$DownloadsFolder\NVidia"
