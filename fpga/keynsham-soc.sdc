# JTAG
set_input_delay  -clock { altera_reserved_tck } 20 [get_ports altera_reserved_tdi]
set_input_delay  -clock { altera_reserved_tck } 20 [get_ports altera_reserved_tms]
set_output_delay -clock { altera_reserved_tck } 20 [get_ports altera_reserved_tdo]
set_false_path -from [get_clocks {altera_reserved_tck}] -to [get_clocks {altera_reserved_tck}]

create_clock -period 20.000 -name clk clk
derive_pll_clocks

# SPI clock
create_generated_clock -name {spi_clk} -source [get_pins {pll|altpll_component|auto_generated|pll1|clk[0]}] -divide_by 2 -master_clock {pll|altpll_component|auto_generated|pll1|clk[0]} [get_registers {keynsham_soc:soc|keynsham_spimaster:spi|spisequencer:seq|spimaster:master|sclk}] 
# SDRAM PLL
create_generated_clock -name sdr_clk -source [get_pins {pll|altpll_component|auto_generated|pll1|clk[1]}] [get_ports {sdr_clk}]
derive_clock_uncertainty

#SDRAM
set_input_delay -clock sdr_clk -max 6.4 [get_ports s_data*]
set_input_delay -clock sdr_clk -min 1.0 [get_ports s_data*]
set_output_delay -clock sdr_clk -max 1.5 [get_ports s_*]
set_output_delay -clock sdr_clk -min -0.8 [get_ports s_*]
set_multicycle_path -from [get_clocks {sdr_clk}] -to [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}] -setup -end 2
set_output_delay -clock [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}] 0 [get_ports {sdr_clk}]

# uart
set_false_path -from [get_ports uart_rx]
set_false_path -to [get_ports uart_tx]

# Status LEDs
set_false_path -to [get_ports running]
set_false_path -to [get_ports spi_cs0_active]
set_false_path -to [get_ports spi_cs1_active]

# SPI bus

set spi_delay_max 1
set spi_delay_min 1
# MOSI
set_output_delay -add_delay -clock {spi_clk} -max [expr $spi_delay_max] [get_ports {spi_mosi1}]
set_output_delay -add_delay -clock {spi_clk} -min [expr $spi_delay_min] [get_ports {spi_mosi1}]
set_output_delay -add_delay -clock {spi_clk} -max [expr $spi_delay_max] [get_ports {spi_mosi2}]
set_output_delay -add_delay -clock {spi_clk} -min [expr $spi_delay_min] [get_ports {spi_mosi2}]
# MISO
set_input_delay -add_delay -clock_fall -clock {spi_clk} -max [expr $spi_delay_max] [get_ports {spi_miso1}]
set_input_delay -add_delay -clock_fall -clock {spi_clk} -min [expr $spi_delay_min] [get_ports {spi_miso1}]
set_input_delay -add_delay -clock_fall -clock {spi_clk} -max [expr $spi_delay_max] [get_ports {spi_miso2}]
set_input_delay -add_delay -clock_fall -clock {spi_clk} -min [expr $spi_delay_min] [get_ports {spi_miso2}]
# CLK
set_output_delay -add_delay -clock {spi_clk} -max [expr $spi_delay_max] [get_ports {spi_clk1}]
set_output_delay -add_delay -clock {spi_clk} -min [expr $spi_delay_min] [get_ports {spi_clk1}]
set_output_delay -add_delay -clock {spi_clk} -max [expr $spi_delay_max] [get_ports {spi_clk2}]
set_output_delay -add_delay -clock {spi_clk} -min [expr $spi_delay_min] [get_ports {spi_clk2}]

set_multicycle_path -setup -start -from [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}] -to [get_clocks {spi_clk}] 1
set_multicycle_path -hold -start -from [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}] -to [get_clocks {spi_clk}] 1
set_multicycle_path -setup -end -from [get_clocks {spi_clk}] -to [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}] 1
set_multicycle_path -hold -end -from [get_clocks {spi_clk}] -to [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}] 1

set_false_path -to [get_ports {spi_ncs*}]

set_false_path -to [get_ports {ethernet_reset_n}]
