
# IAA Setup 
This guide has all the required steps to setup IAA devices on your system if it supports this functionality. It is assumed you have already finished setting up required BIOS comfiguration.

### Steps imvloved:
- Setting up accel-config
- Setting up QPL
- Installing ZSTD
- Building RocksDB from source
- Configuring IAA devices in the system

The scripts in this repository have commands to install packages using apt, if you are using some other package manager, please replace the commands as required.

## Setting up the softwares
The setup of accel-config, QPL. ZSTD, and RocksDB can be done with a single script inlcuded in this repo: `setup_rocksDB_zstd_ubuntu.sh`
You can use it like this:
```
sudo ./setup_rocksDB_zstd_ubuntu.sh WORK_DIR
```
Pass the `WORK_DIR` as a path where you want the different repositories cloned.

## Configuring IAA Devices
There can be multiple IAA devices present on your system, to configure all IAA devices at once, just execute `sudo ./configure_iaa_user.sh`

To verify if devices have been configured, run:
```
accle-config list
```
