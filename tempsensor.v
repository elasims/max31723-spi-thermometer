`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/29/2026 09:53:33 AM
// Design Name: 
// Module Name: tempsensor
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tempsensor(

    input wire clk,
    input wire reset,
    input wire spi_miso,
    output reg spi_ce,
    output reg spi_sclk,
    output reg spi_mosi,
    
    output reg [15:0] temp_data,
    output reg temp_vld
    );
    parameter CLK_FREQ = 125000000;
    parameter SCLK_FREQ = 4000000;
    parameter READ_INTV = 1000;
    localparam READ_PRD = (CLK_FREQ/1000) * READ_INTV;
    localparam DIV = (CLK_FREQ / (2 * SCLK_FREQ) ) - 1;
    
    reg [15:0] divcnt;
    wire TICK = (divcnt == DIV[15:0]);
    
    reg sclk_en;
    always @(posedge clk) begin
      if (reset) begin
        spi_sclk <= 0;
        divcnt <= 0;
      end else if (sclk_en) begin
        if (TICK) begin
          spi_sclk <= ~spi_sclk;
          divcnt <= 0;
        end else begin
          divcnt <= divcnt + 1;
        end
      end else begin
        spi_sclk <= 0;
        divcnt <= 0;
      end
    end
    
    wire rising_edge = sclk_en & TICK & ~spi_sclk;
    wire falling_edge = sclk_en & TICK & spi_sclk;
    
    parameter p_start = 3'd0,
              p_cesetup = 3'd1,
              p_shift = 3'd2,
              p_cehold = 3'd3,
              p_waitread = 3'd4,
              p_read = 3'd5;
    reg [2:0] state;
    reg [7:0] reg_shift;
    reg [3:0] bitcnt;
    reg [1:0] bytecnt;
    reg [7:0] tx_bytes [2:0];
    reg is_read; //1se okuyo 0sa yaziyo
    reg [1:0] total_bytes; //configurelerken 2 byte var, okurken 3 byte var yani bi sonraki byte gec yada ce dusur
    reg [15:0] setup_cnt; //ce1 olduktan sonra scl'nin baslamas? 400ns suruyor
    reg [31:0] period_cnt; //read perioda kadar beklemesini sayiyo
    reg [7:0] rx_byte1;
    reg [7:0] rx_byte2;
    
    always @(posedge clk) begin
      if (reset) begin
        state <= p_start;
        spi_ce <= 0;
        spi_mosi <= 0;
        sclk_en <= 0;
        bitcnt <= 0;
        bytecnt <= 0;
        total_bytes <= 0;
        setup_cnt <= 0;
        //period_cnt <= 0;
        temp_data <= 16'h0000;
        temp_vld <= 1'b0;
        is_read <= 1'b0;
      end else begin
        temp_vld <= 0;
        case (state)
          p_start: begin
            tx_bytes[0] <= 0;
            tx_bytes[1] <= 0;
            total_bytes <= 2;
            bytecnt <= 0;
            bitcnt <= 0;
            reg_shift <= 0;
            spi_ce <= 1; //ce 1 oldugunda communication oluyor
            setup_cnt <= 0;
            state <= p_cesetup;
          end
          p_cesetup: begin
            if (setup_cnt == (CLK_FREQ/2500000)) begin
              spi_mosi <= reg_shift[7];
              state <= p_shift;
              sclk_en <= 1;
            end else begin
              setup_cnt <= setup_cnt + 1;
            end
          end  
          p_shift: begin
            if (rising_edge) begin
             spi_mosi <= reg_shift[7];
            end else if (falling_edge) begin
             reg_shift <= {reg_shift[6:0], spi_miso};
             if (bitcnt == 4'd7)begin
               if (bytecnt == 1) rx_byte1 <= {reg_shift[6:0], spi_miso};
               if (bytecnt == 2) rx_byte2 <= {reg_shift[6:0], spi_miso};
               if (bytecnt == total_bytes - 1) begin
                 sclk_en <= 0;
                 setup_cnt <= 0;
                 state <= p_cehold;
               end else begin
                 bytecnt <= bytecnt + 1;
                 bitcnt <= 0;
                 reg_shift <= is_read ? 0 : tx_bytes[bytecnt + 1];
               end
             end else
               bitcnt <= bitcnt + 1;
            end 
          end
          p_cehold: begin
            if (setup_cnt == (CLK_FREQ / 10_000_000)) begin // sclk1ken ce'yi 0a dusurmek icin 100ns bekliyoruz
              spi_ce <= 0;
              if (is_read) begin
                temp_data  <= {rx_byte2, rx_byte1};
                temp_vld <= 1;
              end
              period_cnt <= 0;
              state <= p_waitread;
            end else
              setup_cnt <= setup_cnt + 1;
          end
        p_waitread: begin
          if (period_cnt == READ_PRD - 1)
            state <= p_read;
          else
            period_cnt <= period_cnt + 1;
        end
        p_read: begin
          tx_bytes[0] <= 1;
          total_bytes <= 3;
          is_read <= 1;
          bytecnt <= 0;
          bitcnt <= 0;
          reg_shift <= 1;
          spi_ce <= 1;
          setup_cnt <= 0;
          state <= p_cesetup;
        end
        endcase
      end
    end
endmodule
