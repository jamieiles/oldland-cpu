set_input_delay  -clock { altera_reserved_tck } 20 [get_ports altera_reserved_tdi]
set_input_delay  -clock { altera_reserved_tck } 20 [get_ports altera_reserved_tms]
set_output_delay -clock { altera_reserved_tck } 20 [get_ports altera_reserved_tdo]
set_false_path -from [get_clocks {altera_reserved_tck}] -to [get_clocks {altera_reserved_tck}]

create_clock -period 20.000 -name clk clk
derive_pll_clocks
create_generated_clock -name sdr_clk -source [get_pins {pll|altpll_component|auto_generated|pll1|clk[1]}] [get_ports {sdr_clk}]
derive_clock_uncertainty
set_input_delay -clock sdr_clk -max 6.4 [get_ports s_data*]
set_input_delay -clock sdr_clk -min 1.0 [get_ports s_data*]
set_output_delay -clock sdr_clk -max 1.5 [get_ports s_*]
set_output_delay -clock sdr_clk -min -0.8 [get_ports s_*]
set_multicycle_path -from [get_clocks {sdr_clk}] -to [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}] -setup -end 2
set_output_delay -clock [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}] 0 [get_ports {sdr_clk}]

# uart
set_false_path -from [get_ports uart_rx]
set_false_path -to [get_ports uart_tx]

set_false_path -to [get_ports running]
