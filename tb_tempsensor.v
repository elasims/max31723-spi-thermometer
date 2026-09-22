`timescale 1ns/1ps

module tb_tempsensor;

    localparam TB_CLK_FREQ  = 10_000_000;
    localparam TB_SCLK_FREQ = 1_000_000;
    localparam TB_READ_INTV = 1;

    reg clk;
    reg reset;

    wire spi_ce;
    wire spi_sclk;
    wire spi_mosi;
    wire spi_miso;

    wire [15:0] temp_data;
    wire        temp_vld;

    tempsensor #(
        .CLK_FREQ (TB_CLK_FREQ),
        .SCLK_FREQ(TB_SCLK_FREQ),
        .READ_INTV(TB_READ_INTV)
    ) dut (
        .clk       (clk),
        .reset     (reset),
        .spi_ce    (spi_ce),
        .spi_sclk  (spi_sclk),
        .spi_mosi  (spi_mosi),
        .spi_miso  (spi_miso),
        .temp_data (temp_data),
        .temp_vld  (temp_vld)
    );

    max31723_model slave (
        .ce   (spi_ce),
        .sclk (spi_sclk),
        .mosi (spi_mosi),
        .miso (spi_miso)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        reset = 1'b1;
        repeat (5) @(posedge clk);
        reset = 1'b0;
    end

    always @(posedge clk) begin
        if (temp_vld)
            $display("[%0t ns] temp_vld=1  temp_data=0x%04h  (MSB=0x%02h LSB=0x%02h)",
                      $time, temp_data, temp_data[15:8], temp_data[7:0]);
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_tempsensor);
    end

    initial begin
        #200000;
        $display("Simulasyon bitti.");
        $finish;
    end

endmodule


module max31723_model (
    input  wire ce,
    input  wire sclk,
    input  wire mosi,
    output reg  miso
);
    reg [23:0] shift; // 8 bit adres icin bosluk + 16 bit sabit sicaklik
    reg [4:0]  cnt;

    initial shift = {8'h00, 8'h80, 8'h19}; // {dummy, LSB, MSB}

    always @(negedge sclk or negedge ce)
        if (!ce) cnt <= 0;
        else if (cnt < 24) cnt <= cnt + 1;

    always @(posedge sclk)
        if (ce && cnt >= 8)
            miso <= shift[23 - cnt];
endmodule
