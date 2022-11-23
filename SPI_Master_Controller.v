module SPI_Master_Controller
	#(parameter SPI_MODE = 2,
	  parameter CLKS_PER_HALF_BIT = 1,
	  parameter MAX_BYTES_PER_CS = 2,
	  parameter CS_INACTIVE_CLKS = 1)
	  
	(
	 input i_Clk,
	 input i_Rst_L,
	 
	 input [$clog2(MAX_BYTES_PER_CS+1)-1:0] i_TX_Count,
	 output [$clog2(MAX_BYTES_PER_CS+1)-1:0] o_RX_Count,
	 input i_DV_To_Master,
	 input i_DV_To_Slave,
	 input [7:0] i_input_To_Master,
	 input [7:0] i_input_To_Slave,
	 output o_Master_Ready,
	 
	 output [7:0] o_output_From_Master,
	 output o_DV_From_Master,
	 output [7:0] o_output_From_Slave,
	 output o_DV_From_Slave
	 );
	 
	 wire MOSI;
	 wire MISO;
	 wire SCLK;
	 wire CS;
	 
	 SPI_Master_With_Single_CS
	 #(.SPI_MODE(SPI_MODE),
	   .CLKS_PER_HALF_BIT(CLKS_PER_HALF_BIT),
		.MAX_BYTES_PER_CS(MAX_BYTES_PER_CS),
		.CS_INACTIVE_CLKS(CS_INACTIVE_CLKS)
	  )SPI_Master_With_Single_CS_Inst
	  (
	  //CONTROL SIGNALS
	   .i_Rst_L(i_Rst_L),
		.i_Clk(i_Clk),
		
	  //MOSI SIGNALS
	   .i_TX_Count(i_TX_Count),
	   .i_TX_Byte(i_input_To_Master),
		.i_TX_DV(i_DV_To_Master),
		.o_TX_Ready(o_Master_Ready),
		
	  //MISO SIGNALS
		.o_RX_DV(o_DV_From_Master),
		.o_RX_Byte(o_output_From_Master),
		.o_RX_Count(o_RX_Count),
	  
	  //SPI INTERFACES
	   .o_SPI_Clk(SCLK),
		.i_SPI_MISO(MISO),
		.o_SPI_MOSI(MOSI),
		.o_SPI_CS_n(CS)
		);
			
	  SPI_Slave
	  #(.SPI_MODE(SPI_MODE)
	   ) SLAVE_INST
	  (
	   //CONTROL SIGNALS
		.i_Clk(i_Clk),
		.i_Rst_L(i_Rst_L),
		
		.i_TX_DV(i_DV_To_Slave),
		.i_TX_Byte(i_input_To_Slave),
		
		.o_RX_DV(o_DV_From_Slave),
		.o_RX_Byte(o_output_From_Slave),
		
		.i_SPI_Clk(SCLK),
		.o_SPI_MISO(MISO),
		.i_SPI_MOSI(MOSI),
		.i_SPI_CS_n(CS)
	  );
	endmodule
	