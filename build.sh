#!/bin/sh

# standard non polarisable
fftool 500 ch.xyz 500 ac.xyz -b 65
packmol < pack.inp
fftool 500 ch.xyz 500 ac.xyz -b 65 -l
cp base.in input_file.lmp
transfer_input -psd in.lmp input_file.lmp

# add drude particles
drude_constructor drude.dff cdrude.dff
polarizer -f cdrude.dff data.lmp pdata.lmp 
# creates pair-drude.lmp
input_polariser input_file.lmp 
# needs pair-drude.lmp
pair_scaler 
# needs key.scl & pair-drude.lmp

# cleanup
rm *pack.xyz in.lmp data.lmp pack.inp pair.bak cdrude.dff
