onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /mkMultBuff_tb/DUT/u_mult_cntrl/state
add wave -noupdate /mkMultBuff_tb/DUT/u_mult_cntrl/next_state
add wave -noupdate -radix binary /mkMultBuff_tb/DUT/u_mult_cntrl/clk
add wave -noupdate -radix binary /mkMultBuff_tb/DUT/u_mult_cntrl/RST_N
add wave -noupdate -radix binary /mkMultBuff_tb/DUT/u_mult_cntrl/EN_mult
add wave -noupdate -radix binary /mkMultBuff_tb/DUT/u_mult_cntrl/EN_mult_pipelined
add wave -noupdate -radix binary /mkMultBuff_tb/DUT/u_mult_cntrl/RDY_mult
add wave -noupdate -radix unsigned /mkMultBuff_tb/DUT/u_mult_cntrl/writeMem_addr
add wave -noupdate /mkMultBuff_tb/DUT/writeMem_val
add wave -noupdate -expand -group mult_16b /mkMultBuff_tb/DUT/u_mult_16b/output_val
add wave -noupdate -expand -group mult_16b /mkMultBuff_tb/DUT/u_mult_16b/EN_mult
add wave -noupdate -expand -group mult_16b /mkMultBuff_tb/DUT/u_mult_16b/mult_input0
add wave -noupdate -expand -group mult_16b /mkMultBuff_tb/DUT/u_mult_16b/mult_input1
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {143750 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {210 ns}
