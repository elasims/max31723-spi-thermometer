set_property -dict {PACKAGE_PIN L16 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 8.000 -name sys_clk_pin -waveform {0.000 4.000} -add [get_ports clk]

set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports reset]

set_property PACKAGE_PIN T14 [get_ports spi_ce_0]
set_property IOSTANDARD LVCMOS33 [get_ports spi_ce_0]
set_property PACKAGE_PIN T15 [get_ports spi_mosi_0]
set_property IOSTANDARD LVCMOS33 [get_ports spi_mosi_0]
set_property PACKAGE_PIN P14 [get_ports spi_miso_0]
set_property IOSTANDARD LVCMOS33 [get_ports spi_miso_0]
set_property PACKAGE_PIN R14 [get_ports spi_sclk_0]
set_property IOSTANDARD LVCMOS33 [get_ports spi_sclk_0]
