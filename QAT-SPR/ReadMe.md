# Setup of QAT and Softwares

This guide will server as a single document for installation and setup of Intel QAT Drivers and their usage with libraries like **openssl, NGINX, and HA Proxy**. We will be only going through the steps for the **Hardware Installation** of QAT. Our system has an **Intel® Xeon® Scalable Processor family with Intel® QAT Gen4/Gen4m** which requires **Hardware v2.0** and the OS is **Ubuntu 22.04**.

## Requirements to smoothly run this guide

- Hardware - **Intel® Xeon® Scalable Processor family with Intel® QAT Gen4/Gen4m**
- OS - **Ubuntu 22.04**

## Assumptions

- BIOS is already configured for the QAT Chip
- **apt** has been configured with any **required proxies**
- Git installed

More info about pre-requisites and installation can be found [here](https://cdrdv2.intel.com/v1/dl/getContent/632506).

## Steps we will be performing in this guide

- Install Intel QAT Driver - This is the main service that will be used by other softwares
- Install Intel QAT Engine for OpenSSL
- Install QATzip for accelaration of compression and decompression
- Install the Intel version of NGINX which is compatible with QAT Accelaration for Encryption, Decryption and Compression, Decompression.
- Install HA Proxy with QAT Accelaration

### Install the QAT Driver

Switch to root user

```
sudo su
```

Install all dependencies

```
sudo apt-get update
sudo apt-get install -y libsystemd-dev
sudo apt-get install -y pciutils-dev
sudo apt-get install -y libudev-dev
sudo apt-get install -y libreadline6-dev
sudo apt-get install -y pkg-config
sudo apt-get install -y libxml2-dev
sudo apt-get install -y pciutils-dev
sudo apt-get install -y libboost-all-dev
sudo apt-get install -y libelf-dev
sudo apt-get install -y libnl-3-dev
sudo apt-get install -y kernel-devel-$(uname -r)
sudo apt-get install -y build-essential
sudo apt-get install -y yasm
sudo apt-get install -y zlib1g-dev
sudo apt-get install -y libssl-dev
```

Now we need to create a working directory where the QAT Driver files will be stored. For this guide we will use `/QAT-Driver`. Now download the latest QAT driver from Intel [here](https://www.intel.com/content/www/us/en/download/765501/intel-quickassist-technology-driver-for-linux-hw-version-2-0.html). Move the `.tar` file into the working directory.

Extract the tarbell file

```
export ICP_ROOT=/QAT-Driver
cd $ICP_ROOT
tar -zxof QAT20.L.*.tar.gz
chmod -R  o-rwx  *
```

Now we prepare the package installation by checking the prerequisites and configuring the build options by running a script using the following command:

```
./configure
```

You can use `./configure --help` to see a list of options.

Build and install the accelaration software with:

```
make -j install
```

Verify the acceleration software kernel objects are loaded and ready to use with this command:

```
lsmod | grep qat

# Ouput - can vary depending on your specific hardware
qat_4xxx 45056 0
intel_qat 331776 2 qat_4xxx,usdm_drv
uio 20480 1 intel_qat
mdev 20480 2 intel_qat,vfio_mdev
vfio 36864 3 intel_qat,vfio_mdev,vfio_iommu_type1
irqbypass 16384 2 intel_qat,kvm
```

Start the QAT Driver service:

```
service qat_service start
```

The configuration files are located at `/etc` directory. The name for the first configuration file for **Intel® QuickAssist Technology Hardware Version 2.0** devices is `4xxx_dev0.conf`.

#### Uninstalling the driver

```
cd $ICP_ROOT
make uninstall
make clean
```

#### Using the script to install

To execute the script you need to download the tarbell in the directory you want to install the Driver. Then execute the script like this:

```
./qat-driver.sh --qat-driver-dir /install/directory
```

### Install QAT Engine for OpenSSL

More detailed steps and information can be found [here](https://github.com/intel/QAT_Engine).

#### Pre-requisites

- Intel QAT Driver to be installed using the above steps.
- Install **OpenSSL 3.0**. This can be installed using the `install-openssl.sh` script. You can use it in this way:

```
sudo ./install-openssl.sh --git-dir ./openssl-git --install-dir /Openssl
```

This will clone the OpenSSL Git repo and install in the specified location.

#### Installing the QAT Engine

Execute the script `qat-engine.sh` provided like this:

```
sudo ./qat-engine.sh --qat-driver-dir /QAT-Driver --openssl-dir /Openssl
```

The QAT Engine uses a different configuration for the QAT Driver. This is located at `/path/to/qat_engine/qat_hw_config`. You would need to do an extra step which is described [here](https://github.com/intel/QAT_Engine#copy-the-intel-quickassist-technology-driver-config-files-for-qat_hw).

If you already had a version of OpenSSL previously installed then before testing OpenSSL with QAT Engine you might need to execute
`export LD_LIBRARY_PATH=$OPENSSL_INSTALL_DIR/lib64` to tell OpenSSL to use the new engines.

You can follow the guidelines for testing [here](https://github.com/intel/QAT_Engine#test-the-intel-quickassist-technology-openssl-engine).

### Install QATzip for OpenSSL

To install QATzip just execute the script `qat-zip.sh` like this:

```
sudo ./qat-zip.sh --qat-driver-dir /QAT-Driver --git-dir /home/username/QAT-Scripts/QATzip
```

Substitute the paths according to your preference.

Read about the installation in detail [here](https://github.com/intel/QATzip#build-intel-quickassist-technology-driver).

### Install NGINX with QAT support

NGINX with QAT is available as a separate [GitHub Repo](https://github.com/intel/asynch_mode_nginx) which needs to built and compiled for using QAT Engine with NGINX.

One step command is to execute the script `nginx-qat.sh`. Make sure you have atleast **QAT Driver, QAT Engine and OpenSSL 3.0** installed. Then execute the script like this:

```
./nginx-qat.sh --qat-driver-dir /QAT-Driver --nginx-install-dir /Nginx --openssl-dir /Openssl --qzip-dir /home/username/QATzip
```

Substitute the paths as per your setup.
