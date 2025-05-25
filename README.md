# NVidia Driver Downloader

Download the latest NVidia driver easily than ever

## Usage

* Run `Download_NVidia_Driver.ps1`
* If the script finds a newer version of NVidia driver it will inform you, download, and expand setup.
* `-Clean` provides a clean driver installation by resetting all NVidia settings to the default ones.

## Addendum

* The script provides the feature to determine your current NVidia videocard and searches for the latest available driver for your card only by parsing the NVidia cloud JSON—not only the latest driver version which is presented on the NVidia DB;
* Downloads always latest 7-Zip version automatically by parsing the SourceForge cloud JSON, expands .MSI as a `portable app without installation` and run it. After creating NVidia setup, 7-Zip will be removed.

## Links

[NVidia drivers](https://www.nvidia.ru/Download/index.aspx)

[NVIDIA GPU UEFI Firmware Update Tool](https://nvidia.custhelp.com/app/answers/list/st/5/kw/NVIDIA%20GPU%20UEFI%20Firmware%20Update%20Tool/sort/4%2C2)

[NVCleanstall](https://www.techpowerup.com/download/techpowerup-nvcleanstall/)
