# temperature-sensor-w-spi

FPGA projects for the Digilent Zybo Z7 (Zynq-7000), covering two hand-written serial interfaces in Verilog:

- **SPI** — MAX31723 digital thermometer
- **I2C** — MAX7304 8-bit I2C GPIO expander, AXI-Lite wrapped and controlled from C over the Zynq PS

## Repository structure

tempsensor.v -- SPI master + MAX31723 driver (config write, periodic temp read)
top.v -- I2C bit-bang engine (START/WRITE/READ/STOP core, AXI-controlled)
myip_iic_ela_v1_0.v -- AXI wrapper top-level (pass-through to S00_AXI)
myip_iic_ela_v1_0_S00_AXI.v -- AXI-Lite register interface driving top.v
zybo_i2c.xdc -- pin constraints (SDA/SCL, clock, reset)
main.c -- Vitis/SDK application: drives the I2C engine via AXI registers


## I2C design

`top.v` implements a generic I2C master core (bit-banged SDA/SCL, open-drain, 4-phase bit timing) exposed as four primitive operations: `START`, `WRITE`, `READ`, `STOP`. All sequencing (device enable, port direction configuration, register reads/writes) is done in software — the core has no built-in transaction logic.

### AXI register map (offset from IP base address)

| Offset | Name  | Access | Description |
|--------|-------|--------|-------------|
| 0x00   | CTRL  | W      | `[1:0]`=op_type, `[9:2]`=wr_data, `[10]`=send_nack. Writing triggers the operation. |
| 0x04   | DONE  | R      | 1 when the last triggered operation has completed. |
| 0x08   | RDATA | R      | Last byte read from the bus. |

`op_type`: `0`=START, `1`=WRITE, `2`=READ, `3`=STOP.

### C usage

`main.c` initializes the MAX7304 (enable GPIOs, set all 8 ports as inputs), then repeatedly prompts over UART which port to check and reports which ports currently read high.

## Build

1. Open the Vivado project, instantiate the packaged IP (`myip_iic_ela`) in a Block Design alongside the Zynq7 Processing System.
2. Run Block/Connection Automation, validate the design, generate the HDL wrapper.
3. Apply `zybo_i2c.xdc`, generate bitstream, export hardware (with bitstream).
4. In Vitis/SDK, create a standalone application, add `main.c`, build and run on hardware.

## Hardware notes

- MAX7304 requires external pull-ups on SDA/SCL (open-drain bus).
- I2C address assumed `AD0 = GND` → 7-bit address `0x1C` (write `0x38`, read `0x39`).
