`timescale 1ns / 1ps

module top(
    input  wire clk,
    input  wire reset,
    inout  wire sda,
    inout  wire scl,

    input  wire        start_op,
    input  wire [1:0]  op_type,
    input  wire [7:0]  wr_data,
    input  wire        send_nack,
    output wire         i2c_done,
    output wire [7:0]   rd_bytes,
    output wire         ack_rcv,
    output wire         i2c_busy
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

    assign scl = scl_low ? 1'b0 : 1'bz;
    assign sda = (sda_low && sda_drive) ? 1'b0 : 1'bz;
    wire sda_in = sda;

    localparam integer Q_PRD = CLK_FREQ / (I2C_FREQ * 4);
    reg [1:0] phase;
    reg phase_tick;
    reg i2c_busy_r;
    reg [15:0] div_cnt;

    always @(posedge clk) begin
      phase_tick <= 1'b0;
      if (reset) begin
        div_cnt <= 0;
        phase <= 0;
      end else if (i2c_busy_r) begin
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

    reg i2c_done_r;
    reg [7:0] rd_bytes_r;
    reg ack_rcv_r;

    reg [2:0] state;
    reg [3:0] bitcnt;
    reg [7:0] reg_shift;
    reg [1:0] cur_op;

    assign i2c_done = i2c_done_r;
    assign rd_bytes = rd_bytes_r;
    assign ack_rcv  = ack_rcv_r;
    assign i2c_busy = i2c_busy_r;

    always @ (posedge clk) begin
      i2c_done_r <= 1'b0;
      if (reset) begin
        state <= p_idle;
        i2c_busy_r <= 0;
        scl_low <= 1'b0;
        sda_low <= 1'b0;
        sda_drive <= 1'b0;
      end
      else begin
        case (state)
         p_idle:
           begin
             i2c_busy_r <= 0;
             if (start_op) begin
              cur_op <= op_type;
              i2c_busy_r <= 1'b1;
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
                    sda_drive <= 1'b1;
                    sda_low <= ~wr_data[7];
                    scl_low <= 1'b1;
                    state <= p_data;
                  end
                  op_read: begin
                    bitcnt <= 0;
                    sda_drive <= 1'b0;
                    scl_low <= 1'b1;
                    state <= p_data;
                  end
                  op_stop: begin
                    sda_drive <= 1'b1;
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
                   sda_low <= ~send_nack; end
           end
               if (phase == 1) scl_low <= 1'b0;
               if (phase == 2 && cur_op == op_write) ack_rcv_r <= sda_in;
               if (phase==3) begin
                   scl_low <= 1'b1;
                   rd_bytes_r <= reg_shift;
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
            i2c_busy_r <= 1'b0;
            i2c_done_r <= 1'b1;
            state <= p_idle;
         end
         default: state <= p_idle;
        endcase
      end
    end

endmodule
