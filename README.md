# NVidia Driver Update
Update NVidia driver easily than ever

## Usage

* Download `nvidia.ps1`
* Right click and select `Run with PowerShell`
* If the script finds a newer version of the nvidia driver online it will download and install it.

### Arguments

* `-Clean` provides a clean installation by resetting all NVidia settings to the default ones

## Addendum

* The script provides the feature to determine your current NVidia videocard and search for the latest available driver for your card only; not the latest drivers version which is presented on the NVidia DB;
* Downloads always latest 7-Zip version automatically, expands .MSI as a portable app and run it. After expanding NVidia setup, 7-Zip will be removed.

## Requirements

No Requirements.

https://www.nvidia.ru/Download/index.aspx
