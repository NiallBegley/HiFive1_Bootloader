# HiFive1_Bootloader

This is a FreedomStudio project that will reflash your SiFive HiFive1's bootloader.

## The Problem

If you have an original SiFive HiFive1 (not the Revision B version) that no longer boots your application after restart but *does* boot your image when you load it from FreedomStudio or the scripts in the freedom-e-sdk repository, it is likely that the HiFive1 bootloader no longer exists on your device.  It is also possible that your HiFive1 shipped without the bootloader entirely (although this is less likely).

The issue here is that the bootloader on the HiFive1 is stored at the beginning of the device's flash memory at memory address 0x2000_0000 so if you - like me - have been playing around with the memory of the device (by messing around with the linker files, installing MyNewt, etc) it is very likely you have blown away your bootloader.  In a normal scenario, the board will boot into the bootloader at 0x2000_0000, run through the bootloader, and then jump to 0x2040_0000 where it expects to find the user's application.  If your bootloader is gone, the board will boot into nothing and won't do anything even though your application might still be installed at 0x2040_0000.  FreedomStudio will boot immediately into your application at 0x2040_0000 if you debug your application through the IDE, which is why you'll still be able to load and debug your own programs, but won't see them start after restarting the device.

## The Solution

I present two ways to solve this problem.  The first is the correct, fallback method that will probably take longer but is more reliable. Below the "Right Way" I'll present instructions for using the FreedomStudio project in this repository

### The Right Way

The *correct* way to solve this problem is laid out below.

1. Clone the v1\_0 branch of the freedom_e_sdk located [here](https://github.com/sifive/freedom-e-sdk/tree/v1_0). Make sure you fetch this branch with the --recursive option.  If you already cloned it and didn't use --recursive, run the following command in your freedom-e-sdk directory:

    ````
    git submodule update --init --recursive
    ````
2. Fetch the required dependencies

    ````
    sudo apt-get install autoconf automake libmpc-dev libmpfr-dev libgmp-dev gawk bison flex texinfo libtool libusb-1.0-0-dev make g++ pkg-config libexpat1-dev zlib1g-dev  
    ````
3. Acquire the tools.  You can build the tools:

    ````
    make tools
    ````

    This took me several hours.  This will build everything you need including the RISCV toolchain and OpenOCD.

    Alternatively, you can download the pre-built tools from [here](https://www.sifive.com/products/tools) (scroll down to the Prebuilt RISC‑V GCC Toolchain section and grab both the toolchain and OpenOCD).  I personally had issues because these pre-built tools are much more up to date than the the repository you cloned.

4. Download and run the bootloader flashing script:

    ````
    curl https://static.dev.sifive.com/dev-tools/flash_bootloader.sh | sh
    ````

    This script - which is included in this repository for posterity - is fairly simple.   It does 3 main things: 
  * Applies a patch to the OpenOCD config file to turn off flash protection on the area of flash reserved for the boot loader 
  * Changes the linker file to load the application into 0x2000\_0000 instead of 0x2040\_0000 
  * Builds and uploads the double\_tap\_dontboot project to the board (double\_tap\_dontboot is the bootloader application).

You should now have the bootloader back on your device.

### The Other Way

So if you're having issues getting the "right way" to work and are looking for another way to restore your bootloader, here is what you do:

1. Clone this repository
2. Open FreedomStudio (make sure it is the latest version)
3. Open this repo but **be careful to closely follow these instructions!**
  * Go to File -> New -> Project...
  * Under C/C++ -> Makefile Project with Existing Code
  *  Click "Browse..." and select the top level of this repo.  Choose the SiFive RISCV-V GNU GCC Newlib toolchain.  Click "Finish."
4. Create a "debug" build configuration.
  * Project -> Build Configurations -> Manage
  * New...
  * Name the new configuration "debug" and copy existing configuration from "Default"
5. Build the project
6. Create a new Run Configuration
  * Run -> Run Configurations...
  * Select SiFive GDB OpenOCD Debugging and hit the "New Launch Configuration" button at the top left
  * Navigate to the "Debugger" tab of this new configuration in the right side panel and verify that the "Config options" under OpenOCD Setup is setup to use bsp/openocd.cfg
7.  Run this configuration.  Make sure your device is connected.

Once run, your bootloader should be back on the device.
