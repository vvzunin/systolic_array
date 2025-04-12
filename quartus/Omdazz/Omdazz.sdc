create_clock -period "50.0 MHz" [get_ports clk]

derive_clock_uncertainty

set_false_path -from reset_n -to [all_clocks]
set_false_path -from rx -to [all_clocks]
set_false_path -from * -to tx

set_false_path -from * -to [get_ports {abcdefgh[*]}]
set_false_path -from * -to [get_ports {digit[*]}]


