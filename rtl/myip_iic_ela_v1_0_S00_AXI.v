	// Address decoding for reading registers
	always @(*)
	begin
	      case ( axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
	        2'h0 : reg_data_out <= {21'h0, ctrl_send_nack, ctrl_wr_data, ctrl_op_type};
	        2'h1 : reg_data_out <= {31'h0, core_i2c_done};
	        2'h2 : reg_data_out <= {24'h0, core_rd_bytes};
	        default : reg_data_out <= 0;
	      endcase
	end

	// Add user logic here

	wire        core_i2c_done;
	wire [7:0]  core_rd_bytes;
	wire        core_ack_rcv;
	wire        core_i2c_busy;

	reg [1:0] ctrl_op_type;
	reg [7:0] ctrl_wr_data;
	reg       ctrl_send_nack;
	wire      ctrl_start = slv_reg_wren && (axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]==2'h0);

	always @(posedge S_AXI_ACLK) begin
	    if (!S_AXI_ARESETN) begin
	        ctrl_op_type   <= 0;
	        ctrl_wr_data   <= 0;
	        ctrl_send_nack <= 0;
	    end else if (ctrl_start) begin
	        ctrl_op_type   <= S_AXI_WDATA[1:0];
	        ctrl_wr_data   <= S_AXI_WDATA[9:2];
	        ctrl_send_nack <= S_AXI_WDATA[10];
	    end
	end

	top core (
	    .clk       (S_AXI_ACLK),
	    .reset     (~S_AXI_ARESETN),
	    .sda       (sda),
	    .scl       (scl),
	    .start_op  (ctrl_start),
	    .op_type   (ctrl_op_type),
	    .wr_data   (ctrl_wr_data),
	    .send_nack (ctrl_send_nack),
	    .i2c_done  (core_i2c_done),
	    .rd_bytes  (core_rd_bytes),
	    .ack_rcv   (core_ack_rcv),
	    .i2c_busy  (core_i2c_busy)
	);

	// User logic ends
