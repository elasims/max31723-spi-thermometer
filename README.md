# max31723-spi-thermometer

FPGA project for the Digilent Zybo Z7 (Zynq-7000): a hand-written SPI
master in Verilog reading a MAX31723 digital thermometer, exposed as an
AXI-Lite IP and read out over the Zynq PS via C.

## Files

| File | Description |
|------|--------------|
| `tempsensor.v` | SPI master + MAX31723 driver. Writes the config register (enables continuous conversion), then periodically reads the temperature register (address + LSB + MSB burst). |
| `myip_spi_ela_v1_0.v` | AXI wrapper top-level (pass-through to S00_AXI). |
| `myip_spi_ela_v1_0_S00_AXI.v` | AXI-Lite register interface driving `tempsensor.v`. |
| `zybo_spi.xdc` | Pin constraints (SPI lines, clock, reset). |
| `main.c` | Vitis/SDK application: polls the status register and prints the temperature over UART. |

## Protocol

MAX31723 communicates over SPI, Mode 1 (CPOL=0, CPHA=1), MSB-first.

- Config register (`0x80` write): SD=0 enables continuous conversion (device
  ships in shutdown mode by default).
- Temperature register (`0x01` read, burst LSB then MSB): 16-bit two's
  complement, 9-bit resolution by default.

## AXI register map (offset from IP base address)

| Offset | Name  | Access | Description |
|--------|-------|--------|-------------|
| 0x00   | TEMP_DATA | R  | Last read 16-bit temperature value ({MSB, LSB}). |
| 0x04   | STATUS    | R  | Bit 0: new data ready (cleared on read). |

## C usage

`main.c` polls the STATUS register; when new data is ready, it reads
TEMP_DATA, converts it (`signed_raw / 256.0`), and prints the temperature
over UART every ~100ms.

## Build

1. Package `tempsensor.v` inside the AXI-Lite wrapper (`myip_spi_ela`) and
   add it to the IP repository.
2. In a Block Design, instantiate the IP alongside the Zynq7 Processing
   System, run Block/Connection Automation, validate, create the HDL
   wrapper.
3. Apply `zybo_spi.xdc`, generate bitstream, export hardware with bitstream.
4. In Vitis/SDK, create a standalone application, add `main.c`, build and
   run on hardware.

## Hardware notes

- MAX31723 CE must be held high for the full transfer, with tCC (~400ns)
  setup before SCLK starts and tCCH (~100ns) hold after the last SCLK edge.
- SCLK kept at 4MHz (datasheet max 5MHz) for timing margin.
