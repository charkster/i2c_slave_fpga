# i2c_slave_fpga
Systemverilog implementation of an I2C slave with a simple register map. Multi-byte reads and writes supported with address auto-increment. 

I will get around to including the simulation environment, it needs to be cleaned-up a little more. I have tasks to emulate the I2C master which allows the testbench to be very high-level.
This slave implementation has been tested with FT4222 and Raspberry Pi I2C masters.

I wanted to make a simple framework for future projects that require an I2C interface. Feel free to take as much or as little of the code as you want.
