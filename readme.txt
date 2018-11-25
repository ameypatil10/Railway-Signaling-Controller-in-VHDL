GECKO

VHDL
The project is compiled using ISE

PYTHON
Instead of main.c , python files have been used which have been provided in the python folder. These files and commands should be run from the makestuff/libs/libfpgalink/examples/python/ directory

To run the python files, use the command sudo LD_LIBRARY_PATH = ../../lin.x64/rel python3 lab6.py

To make the dependencies of the libfpga folders
cd ../../../libusbwrap/ && make deps && cd ../libfpgalink/ && make deps && cp ../libusbwrap/lin.x64/rel/libusbwrap.so lin.x64/rel/libusbwrap.so && make deps

UART
we are doing the optional part. The neighbouring controllers send the slider input when they are in S5
