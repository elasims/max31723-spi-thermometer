	// reg_data_out case'i (mevcut default case'in yerine):
	case ( axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
	  2'h0   : reg_data_out <= {16'h0, reg_temp_data};
	  2'h1   : reg_data_out <= {31'h0, reg_data_ready};
	  default : reg_data_out <= 0;
	endcase

	// Add user logic here
	wire [15:0] core_temp_data;
	wire        core_temp_vld;

	tempsensor # (
	    .CLK_FREQ(125000000),
	    .SCLK_FREQ(4000000),
	    .READ_INTV(1000)
	) core (
	        .clk (S_AXI_ACLK),
	        .reset (~S_AXI_ARESETN),
	        .spi_ce (spi_ce),
	        .spi_sclk (spi_sclk),
	        .spi_mosi (spi_mosi),
	        .spi_miso (spi_miso),
	        .temp_data (core_temp_data),
	        .temp_vld (core_temp_vld)
	);

	reg [15:0] reg_temp_data;
	reg reg_data_ready;

	always @(posedge S_AXI_ACLK) begin
	  if (!S_AXI_ARESETN) begin
	    reg_temp_data <= 16'h0;
	    reg_data_ready <= 0;
	  end else begin
	    if (core_temp_vld) begin
	      reg_temp_data <= core_temp_data;
	      reg_data_ready <= 1;
	    end
	    if (slv_reg_rden && axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 2'h1)
	      reg_data_ready <= 0;
	  end
	end
	// User logic ends
