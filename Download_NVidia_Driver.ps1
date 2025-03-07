<#
	.SYNOPSIS
	Check for the latest NVIdia driver version, and if it's lower than the current one download

	.PARAMETER Clean
	Delete the old driver, reset settings and install the newest one

	.EXAMPLE
	UpdateNVidiaDriver

	.NOTES
	Supports Windows 10 x64 & Windows 11 only
 
	.NOTES
	Installer 2.0 Command Line Guide

	.NOTES
	https://docs.nvidia.com/sdk-manager/sdkm-command-line-install/index.html
#>
function UpdateNVidiaDriver
{
	Clear-Host

	# Checking Windows version
	if ([System.Version][Environment]::OSVersion.Version.ToString() -lt [System.Version]"10.0")
	{
		Write-Verbose -Message "Your Windows is unsupported. Upgrade to Windows 10 or higher" -Verbose
		exit
	}

	# Checking Windows bitness
	if (-not [Environment]::Is64BitOperatingSystem)
	{
		Write-Verbose -Message "Your Windows architecture is x86. x64 is required" -Verbose
		exit
	}

	if (Test-Path -Path "$env:SystemRoot\System32\DriverStore\FileRepository\nv_*\nvidia-smi.exe")
	{
		# The NVIDIA System Management Interface (nvidia-smi) is a command line utility, based on top of the NVIDIA Management Library (NVML)
		$CurrentDriverVersion = nvidia-smi.exe --format=csv,noheader --query-gpu=driver_version
	}
	else
	{
		[System.Version]$Driver = (Get-CimInstance -ClassName Win32_VideoController | Where-Object -FilterScript {$_.Name -match "NVIDIA"}).DriverVersion
		$CurrentDriverVersion = ("{0}{1}" -f $Driver.Build, $Driver.Revision).Substring(1).Insert(3,'.')
	}

	Write-Verbose -Message "Current version: $CurrentDriverVersion" -Verbose
	Write-Information -MessageData "" -InformationAction Continue

	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

	if ($Host.Version.Major -eq 5)
	{
		# Progress bar can significantly impact cmdlet performance
		# https://github.com/PowerShell/PowerShell/issues/2138
		$Script:ProgressPreference = "SilentlyContinue"
	}

	# Checking latest driver version from Nvidia website
	$Parameters = @{
		Uri             = "https://www.nvidia.com/Download/API/lookupValueSearch.aspx?TypeID=3"
		UseBasicParsing = $true
	}
	[xml]$Content = (Invoke-WebRequest @Parameters).Content
	$CardModelName = (Get-CimInstance -ClassName CIM_VideoController | Where-Object -FilterScript {($_.AdapterDACType -notmatch "Internal") -and ($_.Status -eq "OK")}).Caption.Split(" ")
	if (-not $CardModelName)
	{
		Write-Verbose -Message "There's no active videocard in system" -Verbose
		exit
	}

	# Remove the first word in full model name. E.g. "NVIDIA"
	$CardModelName = [string]$CardModelName[1..($CardModelName.Count)]
	$ParentID = ($Content.LookupValueSearch.LookupValues.LookupValue | Where-Object -FilterScript {$_.Name -contains $CardModelName}).ParentID | Select-Object -First 1
	$Value = ($Content.LookupValueSearch.LookupValues.LookupValue | Where-Object -FilterScript {$_.Name -contains $CardModelName}).Value | Select-Object -First 1

	# https://github.com/fyr77/EnvyUpdate/wiki/Nvidia-API
	# osID=57 — Windows x64/Windows 11
	# languageCode=1033 — English language
	# dch=1 — DCH drivers
	# https://nvidia.custhelp.com/app/answers/detail/a_id/4777/~/nvidia-dch%2Fstandard-display-drivers-for-windows-10-faq
	# upCRD=0 — Game Ready Driver
	$Parameters = @{
		Uri             = "https://gfwsl.geforce.com/services_toolkit/services/com/nvidia/services/AjaxDriverService.php?func=DriverManualLookup&psid=$ParentID&pfid=$Value&osID=57&languageCode=1033&beta=null&isWHQL=1&dltype=-1&dch=1&upCRD=0"
		UseBasicParsing = $true
	}
	$Data = Invoke-RestMethod @Parameters

	if ($Data.IDS.downloadInfo.Version)
	{
		$LatestVersion = $Data.IDS.downloadInfo.Version
		Write-Verbose -Message "Latest version: $LatestVersion" -Verbose
		Write-Information -MessageData "" -InformationAction Continue
	}
	else
	{
		Write-Warning -Message "Something went wrong"
		exit
	}

	# Comparing installed driver version to latest driver version from Nvidia
	if (-not $Clean -and ([System.Version]$LatestVersion -eq [System.Version]$CurrentDriverVersion))
	{
		Write-Verbose -Message "The current installed NVidia driver is the same as the latest one" -Verbose
		exit
	}

	$DownloadsFolder = Get-ItemPropertyValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "{374DE290-123F-4565-9164-39C4925E467B}"
	if (-not (Test-Path -Path "$DownloadsFolder\$LatestVersion-desktop-win10-win11-64bit-international-dch-whql.exe"))
	{
		# Downloading installer
		try
		{
			$Parameters = @{
				Uri             = $Data.IDS.downloadInfo.DownloadURL
				OutFile         = "$DownloadsFolder\$LatestVersion-desktop-win10-win11-64bit-international-dch-whql.exe"
				UseBasicParsing = $true
				Verbose         = $true
			}
			Invoke-WebRequest @Parameters
		}
		catch [System.Net.WebException]
		{
			Write-Warning -Message "Connection cannot be established"
			exit
		}
	}

	Write-Warning -Message "Downloading..."
 	Write-Warning -Message $Data.IDS.downloadInfo.DownloadURL

	# Get the latest 7-Zip download URL
	try
	{
		$Parameters = @{
			Uri             = "https://sourceforge.net/projects/sevenzip/best_release.json"
			UseBasicParsing = $true
			Verbose         = $true
		}
		$bestRelease = (Invoke-RestMethod @Parameters).platform_releases.windows.filename.replace("exe", "msi")
	}
	catch [System.Net.WebException]
	{
		Write-Warning -Message "Connection cannot be established"
		exit
	}

	# Download the latest 7-Zip x64
	try
	{
		$Parameters = @{
			Uri             = "https://unlimited.dl.sourceforge.net/project/sevenzip$($bestRelease)?viasf=1"
			OutFile         = "$DownloadsFolder\7Zip.msi"
			UseBasicParsing = $true
			Verbose         = $true
		}
		Invoke-WebRequest @Parameters
	}
	catch [System.Net.WebException]
	{
		Write-Warning -Message "Connection cannot be established"
		exit
	}

	# Expand 7-Zip
	$Arguments = @(
		"/a `"$DownloadsFolder\7Zip.msi`""
		"TARGETDIR=`"$DownloadsFolder\7zip`""
		"/qb"
	)
	Start-Process "msiexec" -ArgumentList $Arguments -Wait

	# Delete the installer once it completes
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
		"$DownloadsFolder\$LatestVersion-desktop-win10-win11-64bit-international-dch-whql.exe",
		# Extract these files and folders
		"Display.Driver HDAudio NVI2 NVApp NVApp.MessageBus NVCpl PhysX EULA.txt ListDevices.txt setup.cfg setup.exe",
		# Specifies a destination directory where files are to be extracted
		"-o`"$DownloadsFolder\NVidia`""
	)
	$Parameters = @{
		FilePath     = "$DownloadsFolder\7zip\Files\7-Zip\7z.exe"
		ArgumentList = $Arguments
		NoNewWindow  = $true
		Wait         = $true
	}
	Start-Process @Parameters

	# Remove unnecessary dependencies from setup.cfg
	[xml]$setup = Get-Content -Path "$DownloadsFolder\NVidia\setup.cfg" -Encoding UTF8 -Force
	($setup.setup.manifest.file | Where-Object -FilterScript {@("`${{EulaHtmlFile}}", "`${{FunctionalConsentFile}}", "`${{PrivacyPolicyFile}}") -contains $_.name }) | ForEach-Object {
		$_.ParentNode.RemoveChild($_)
	}
	$setup.Save("$DownloadsFolder\NVidia\setup.cfg")

	# Re-save in the UTF-8 without BOM encoding to make it work
	if ($Host.Version.Major -eq 5)
	{
		Set-Content -Value (New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false).GetBytes($(Get-Content -Path "$DownloadsFolder\NVidia\setup.cfg" -Raw)) -Encoding Byte -Path "$DownloadsFolder\NVidia\setup.cfg" -Force
	}
	else
	{
		(Get-Content -Path "$DownloadsFolder\NVidia\setup.cfg" -Encoding utf8NoBOM) | Set-Content -Path "$DownloadsFolder\NVidia\setup.cfg" -Encoding utf8NoBOM -Force
	}

	$Parameters = @{
		Path    = "$DownloadsFolder\7zip", "$DownloadsFolder\$LatestVersion-desktop-win10-win11-64bit-international-dch-whql.exe"
		Recurse = $true
		Force   = $true
	}
	Remove-Item @Parameters

	Invoke-Item -Path "$DownloadsFolder\NVidia"
}

UpdateNVidiaDriver
