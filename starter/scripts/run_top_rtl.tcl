
if {![info exists RUN_NAME]} { set RUN_NAME 400 }

set TOP_LEVEL mkMultBuff
set TB_NAME   mkMultBuff_tb
set SDF_FILE  ./submission/outputs/${TOP_LEVEL}_${RUN_NAME}_map.sdf
set VCD_FILE  ./submission/outputs/${TOP_LEVEL}_${RUN_NAME}.vcd

# Launch simulation with SDF back-annotation
vsim -default_radix signed \
     -voptargs=+acc \
     -l submission/outputs/${TB_NAME}_${RUN_NAME}.sim.log \
     work.$TB_NAME

# VCD dump for power analysis (feed to vcd2saif_run.csh afterwards)
vcd file $VCD_FILE
vcd add /$TB_NAME/DUT/*

# Waveforms (interactive only - skipped in -batch)
add wave -label CLK -position insertpoint sim:/$TB_NAME/DUT/clk

add wave -divider "Multiply Interface"
add wave -label mult0 -position insertpoint sim:/$TB_NAME/DUT/mult_input0
add wave -label mult1 -position insertpoint sim:/$TB_NAME/DUT/mult_input1

add wave -divider "Output"
add wave -label VALID_memVal -position insertpoint sim:/$TB_NAME/DUT/VALID_memVal
add wave -label memVal_data  -position insertpoint sim:/$TB_NAME/DUT/memVal_data

run -all
vcd flush
