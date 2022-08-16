# NVidia Driver Update
Update NVidia driver easily than ever

## Usage

* Run `UpdateNVidiaDriver.ps1`
* If the script finds a newer version of NVidia driver it will inform you, download it, expand setup, and install it.

### Arguments

* `-Clean` provides a clean installation by resetting all NVidia settings to the default ones.

## Addendum

* The script provides the feature to determine your current NVidia videocard and search for the latest available driver for your card only—not only the latest driver version which is presented on the NVidia DB;
* Downloads always latest 7-Zip version automatically, expands .MSI as a portable app and run it. After expanding NVidia setup, 7-Zip will be removed.

## NVidia driver update link

<https://www.nvidia.ru/Download/index.aspx>
