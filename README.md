# rfkit

Verilog HDL modules for use in RF projects.

## Install Verible

This kit uses [Verible](https://github.com/chipsalliance/verible) for linting.
Verible includes a language server, which can be used to integrate into VSCode.
https://github.com/chipsalliance/verible/blob/master/verilog/tools/ls/README.md


To install the released Verible VSCode extension, run this command from the
quick-open menu (ctrl-p):

```
ext install CHIPSAlliance.verible
```

The rfkit project has a custom set of verible linter rules. To make verible up
those rules, add the "--rules_config_search" argument. This can be done in the
VSCode settings page for the Verible extension.

## Install VUnit

This kit uses the [VUnit](https://vunit.github.io/) testing framework for all
testbenches. VUnit is written in Python and relies on 3rd-party HDL simulators
to do the actual test execution.

To install VUnit itself:

```
pip3 install vunit_hdl
```

## Install ModelSim-Intel

VUnit requires a compatible HDL simulator installed and available in the PATH.
The free version of ModelSim-Intel seems to work well and is available here:

https://www.intel.com/content/www/us/en/software-kit/750666/modelsim-intel-fpgas-standard-edition-software-version-20-1-1.html

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

## Run VUnit testbenches

`run_vunit.py` finds and runs all testbenches in the `src/` folder.

```
python3 run_vunit.py
```

