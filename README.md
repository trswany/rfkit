# rfkit

Verilog HDL modules for use in RF projects.

## Install Verilog simulator

VUnit requires a compatible HDL simulator installed and available in the PATH.
The free version of ModelSim-Intel seems to work well and is available here:

[Intel ModelSim] https://www.intel.com/content/www/us/en/software-kit/750666/modelsim-intel-fpgas-standard-edition-software-version-20-1-1.html)

Install ModelSim and then add the `modelsim_ase/bin` folder to your path.
Alternatively, you can export the path in VUNIT_MODELSIM_PATH for VUnit.

```
export VUNIT_MODELSIM_PATH=/home/trswany/intelFPGA/20.1/modelsim_ase/bin
```

ModelSim is provided as 32-bit binaries, which means that you'll need to
install 32-bit versions of all of the libraries that it needs. If you get
`No such file or directory` errors, this is probably the problem. To install
the correct libraries:

```
sudo dpkg --add-architecture i386
sudo apt-get install libc6:i386 libncurses5:i386 libstdc++6:i386 libxext6:i386 libxft2:i386
```

## Install VUnit

```
pip3 install vunit
```

## Run VUnit testbenches

```
python3 run_vunit.py
```

