#!/bin/bash

SOURCE="../src/driver_ad5328.v ./driver_ad5328_tb.sv"
TOP="driver_ad5328_tb"

iverilog -o sim.vvp -s $TOP -g2012 $SOURCE 
vvp sim.vvp 
rm sim.vvp

