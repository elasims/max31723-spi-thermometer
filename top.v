`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/30/2026 02:26:55 PM
// Design Name: 
// Module Name: top
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


module spi(
    input wire clk,
    input wire reset,
    inout wire sda,
    inout wire scl
    );
    parameter CLK_FREQ = 125000000;
    parameter I2C_FREQ = 100000;
    localparam slave_addr_w = 8'h38;
    localparam slave_addr_r = 8'h39;
    localparam reg_global_cfg = 8'h40;
    localparam reg_direction = 8'h34;
    localparam reg_values = 8'h3A;
    
    localparam p_idle = 3'd0,
           p_start = 3'd1,
           p_data = 3'd2,
           p_stop = 3'd3,
           p_acknack = 3'd4,
           p_done = 3'd5;
           
    localparam op_start = 2'd0,
               op_write = 2'd1,
               op_read = 2'd2,
               op_stop = 2'd3;

    reg scl_low;
    reg sda_low;
    reg sda_drive;
    
    assign scl = scl_low ? 1'b0 : 1'bz;     //low yada serbest
    assign sda = (sda_low && sda_drive) ? 1'b0 : 1'bz;
    wire sda_in = sda;
    
    localparam integer Q_PRD = CLK_FREQ / (I2C_FREQ * 4);
    reg [1:0] phase;
    reg phase_tick;
    reg i2c_busy;
    reg [15:0] div_cnt;
    
    always @(posedge clk) begin
      phase_tick <= 1'b0;
      if (reset) begin
        div_cnt <= 0;
        phase <= 0;
      end else if (i2c_busy) begin
        if (div_cnt == Q_PRD - 1) begin
          div_cnt <= 0;
          phase <= phase + 1;
          phase_tick <= 1'b1;
        end else begin
          div_cnt <= div_cnt + 1;
        end
      end else begin
        div_cnt <= 0;
        phase <= 0; 
      end
    end
    
    reg i2c_done;
    reg [2:0] state;
    reg [3:0] bitcnt;
    reg [7:0] reg_shift;
    reg [1:0] cur_op;
    reg [1:0] op_type;
    reg [7:0] rd_bytes;
    reg [7:0] wr_data;
    reg start_op;
    reg send_nack;
    reg ack_rcv;
    
    always @ (posedge clk) begin
      i2c_done <= 1'b0;
      if (reset) begin
        state <= p_idle;
        i2c_busy <= 0;
        scl_low <= 1'b0;
        sda_low <= 1'b0;
        sda_drive <= 1'b0;
      end
      else begin
        case (state)
         p_idle:
           begin
             i2c_busy <= 0;
             if (start_op) begin
              cur_op <= op_type;
              i2c_busy <= 1'b1;
              case (op_type)
                  op_start: begin
                    sda_drive <= 1'b1;
                    sda_low <= 1'b0;
                    scl_low <= 0;
                    state <= p_start;
                  end
                  op_write: begin
                    reg_shift <= wr_data;
                    bitcnt <= 0;
                    sda_drive <= 1'b1; //yazma islemi
                    sda_low <= ~wr_data[7]; //yazdigimiz data neyse sda'i ona esitliyoruz
                    scl_low <= 1'b1; //datanin degismesi icin scl must be low
                    state <= p_data;
                  end
                  op_read: begin
                    bitcnt <= 0;
                    sda_drive <= 1'b0;
                    scl_low <= 1'b1;
                    state <= p_data;
                  end
                  op_stop: begin
                    sda_drive <= 1'b1; //when master is controlling, sda_drive = 1
                    sda_low <= 1'b1;
                    scl_low <= 1'b1;
                    state <= p_stop;
                  end
                endcase
             end
           end
         p_start: begin
           if (phase == 1) scl_low <= 1'b0;
           if (phase == 2) sda_low <= 1'b1;
           if (phase == 3) begin scl_low <= 1'b1; state <= p_done; end
         end
         p_data: begin
           if (phase_tick) begin
             if (phase == 1) scl_low <= 1'b0;
             if (phase == 2 && cur_op == op_read) reg_shift[7 - bitcnt] <= sda_in; 
             if (phase == 3) begin
               scl_low <= 1'b1;
               if (bitcnt == 3'd7) begin
                 state <= p_acknack;
               end else begin
                 bitcnt <= bitcnt + 1;
                 if (cur_op == op_write) sda_low <= ~reg_shift[6 - bitcnt];
               end 
             end
           end
         end
         p_acknack: begin
           if (phase == 0) begin
               if (cur_op == op_write) sda_drive <= 1'b0;
                 else begin sda_drive <= 1'b1; 
                   sda_low <= ~send_nack; end  //send nack when sda is high
               end
               if (phase == 1) scl_low <= 1'b0;
               if (phase == 2 && cur_op == op_write) ack_rcv <= sda_in;
               if (phase==3) begin
                   scl_low <= 1'b1; 
                   rd_bytes <= reg_shift; 
                   state <= p_done;
               end
         end
         p_stop: begin
           if (phase_tick) begin
              if (phase==1) scl_low <= 1'b0;
              if (phase==3) begin 
                sda_low <= 1'b0; 
                state <= p_done; 
              end
           end
         end
         p_done: begin
            i2c_busy <= 1'b0; 
            i2c_done <= 1'b1; 
            state <= p_idle;
         end
         default: state <= p_idle;
        endcase
      end
    end

    
    reg [1:0] prog_op   [0:21];
    reg [7:0] prog_data [0:21];

    initial begin
        // --- enable yaz (0x40 <- 0x10) ---
        prog_op[0]=op_start; prog_data[0]=8'h00;
        prog_op[1]=op_write; prog_data[1]=slave_addr_w;
        prog_op[2]=op_write; prog_data[2]=reg_global_cfg;
        prog_op[3]=op_write; prog_data[3]=8'h10;
        prog_op[4]=op_stop;  prog_data[4]=8'h00;
        // --- direction yaz (0x34 <- 0x02) ---
        prog_op[5]=op_start; prog_data[5]=8'h00;
        prog_op[6]=op_write; prog_data[6]=slave_addr_w;
        prog_op[7]=op_write; prog_data[7]=reg_direction;
        prog_op[8]=op_write; prog_data[8]=8'h02;
        prog_op[9]=op_stop;  prog_data[9]=8'h00;
        // --- buton oku (0x3A), repeated start ile --- (donguye buradan giriyoruz)
        prog_op[10]=op_start; prog_data[10]=8'h00;
        prog_op[11]=op_write; prog_data[11]=slave_addr_w;
        prog_op[12]=op_write; prog_data[12]=reg_values;
        prog_op[13]=op_start; prog_data[13]=8'h00;
        prog_op[14]=op_write; prog_data[14]=slave_addr_r;
        prog_op[15]=op_read;  prog_data[15]=8'h00;
        prog_op[16]=op_stop;  prog_data[16]=8'h00;
        // --- LED yaz (0x3A <- ...) ---
        prog_op[17]=op_start; prog_data[17]=8'h00;
        prog_op[18]=op_write; prog_data[18]=slave_addr_w;
        prog_op[19]=op_write; prog_data[19]=reg_values;
        prog_op[20]=op_write; prog_data[20]=8'h00; // gercek deger asagida hesaplanacak
        prog_op[21]=op_stop;  prog_data[21]=8'h00;
    end

    localparam LOOP_START = 5'd10;
    localparam READ_STEP  = 5'd15;
    localparam LED_STEP   = 5'd20;
    localparam LAST_STEP  = 5'd21;

    reg [4:0]  step;
    reg        seq_busy;
    reg        button_val;
    reg [31:0] wait_cnt;
    localparam WAIT_CYCLES = CLK_FREQ / 20;

    always @(posedge clk) begin
        start_op <= 1'b0;

        if (reset) begin
            step       <= 0;
            seq_busy   <= 1'b0;
            wait_cnt   <= 0;
            button_val <= 0;
        end

        else if (seq_busy) begin
            if (i2c_done) begin
                if (step == READ_STEP) button_val <= rd_bytes[0];
                seq_busy <= 1'b0;
                step     <= (step == LAST_STEP) ? 5'd22 : step + 1;
            end
        end

        else if (step == 5'd22) begin
            if (wait_cnt == WAIT_CYCLES - 1) begin
                wait_cnt <= 0;
                step     <= LOOP_START;
            end else
                wait_cnt <= wait_cnt + 1;
        end

        else begin
            op_type   <= prog_op[step];
            wr_data   <= (step == LED_STEP) ? {6'b0, button_val, 1'b0} : prog_data[step];
            send_nack <= (step == READ_STEP);
            start_op  <= 1'b1;
            seq_busy  <= 1'b1;
        end
    end

endmodule
