module SPI_Master
  #(parameter SPI_MODE = 0,
    parameter CLKS_PER_HALF_BIT = 2)
  (
   input        i_Rst_L, 
   input        i_Clk,    
   
   // TX (MOSI) Signals
   input [7:0]  i_TX_Byte,        
   input        i_TX_DV,      
   output reg   o_TX_Ready,  
   
   // RX (MISO) Signals
   output reg       o_RX_DV,     
   output reg [7:0] o_RX_Byte, 
	
   // SPI Interfacing Signals
   output reg o_SPI_Clk,
   input      i_SPI_MISO,
   output reg o_SPI_MOSI
   );

  // SPI Interface for MODE selection
  wire w_CPOL;     // Clock polarity
  wire w_CPHA;     // Clock phase

  reg [$clog2(CLKS_PER_HALF_BIT*2)-1:0] r_SPI_Clk_Count;
  reg [4:0] r_SPI_Clk_Edges;
  reg 		r_Leading_Edge;
  reg 		r_Trailing_Edge;

  reg 		r_SPI_Clk;
  reg       r_TX_DV;
  reg [7:0] r_TX_Byte;

  reg [2:0] r_RX_Bit_Count;
  reg [2:0] r_TX_Bit_Count;

  //  Mode | Clock Polarity (CPOL/CKP) | Clock Phase (CPHA)
  //   0   |             0             |        0
  //   1   |             0             |        1
  //   2   |             1             |        0
  //   3   |             1             |        1
  assign w_CPOL  = (SPI_MODE == 2) | (SPI_MODE == 3);
  assign w_CPHA  = (SPI_MODE == 1) | (SPI_MODE == 3);

  // Generation of SPI CLOCK when DATA VALID (DV) Pulse comes
  always @(posedge i_Clk or negedge i_Rst_L)
  begin
    if (~i_Rst_L)
    begin
      o_TX_Ready      <= 1'b0;
      r_Leading_Edge  <= 1'b0;
      r_Trailing_Edge <= 1'b0;
      r_SPI_Clk       <= w_CPOL; 
      r_SPI_Clk_Edges <= 0;
		r_SPI_Clk_Count <= 0;
    end
    else
    begin
      r_Leading_Edge  <= 1'b0;
      r_Trailing_Edge <= 1'b0;
      
      if (i_TX_DV)
      begin
        o_TX_Ready      <= 1'b0;
        r_SPI_Clk_Edges <= 16;  // Total edges in one byte ALWAYS 16
      end
      else if (r_SPI_Clk_Edges > 0)
      begin
        o_TX_Ready <= 1'b0;
        if (r_SPI_Clk_Count == CLKS_PER_HALF_BIT*2-1)
        begin
          r_SPI_Clk_Edges <= r_SPI_Clk_Edges - 1'b1;
          r_Trailing_Edge <= 1'b1;
          r_SPI_Clk_Count <= 0;
          r_SPI_Clk       <= ~r_SPI_Clk;
        end
        else if (r_SPI_Clk_Count == CLKS_PER_HALF_BIT-1)
        begin
          r_SPI_Clk_Edges <= r_SPI_Clk_Edges - 1'b1;
          r_Leading_Edge  <= 1'b1;
          r_SPI_Clk_Count <= r_SPI_Clk_Count + 1'b1;
          r_SPI_Clk       <= ~r_SPI_Clk;
        end
        else
        begin
          r_SPI_Clk_Count <= r_SPI_Clk_Count + 1'b1;
        end
      end  
      else
      begin
        o_TX_Ready <= 1'b1;
      end  
    end // else: !if(~i_Rst_L)
  end // always @ (posedge i_Clk or negedge i_Rst_L)

  // Keeping local storage of byte.
  always @(posedge i_Clk or negedge i_Rst_L)
  begin
    if (~i_Rst_L)
    begin
      r_TX_Byte <= 8'h00;
      r_TX_DV   <= 1'b0;
    end
    else
      begin
        r_TX_DV <= i_TX_DV; 
        if (i_TX_DV)
        begin
          r_TX_Byte <= i_TX_Byte;
        end
      end // else: !if(~i_Rst_L)
  end // always @ (posedge i_Clk or negedge i_Rst_L)

  // Transmission (MOSI)
  always @(posedge i_Clk or negedge i_Rst_L)
  begin
    if (~i_Rst_L)
    begin
      o_SPI_MOSI     <= 1'b0;
      r_TX_Bit_Count <= 3'b111; // Sending the MSB first
    end
    else
    begin
      if (o_TX_Ready)
      begin
        r_TX_Bit_Count <= 3'b111;
      end
      else if (r_TX_DV & ~w_CPHA)
      begin
        o_SPI_MOSI     <= r_TX_Byte[3'b111];
        r_TX_Bit_Count <= 3'b110;
      end
      else if ((r_Leading_Edge & w_CPHA) | (r_Trailing_Edge & ~w_CPHA))
      begin
        r_TX_Bit_Count <= r_TX_Bit_Count - 1'b1;
        o_SPI_MOSI     <= r_TX_Byte[r_TX_Bit_Count];
      end
    end
  end

  // Reception (MISO)
  always @(posedge i_Clk or negedge i_Rst_L)
  begin
    if (~i_Rst_L)
    begin
      o_RX_Byte      <= 8'h00;
      o_RX_DV        <= 1'b0;
      r_RX_Bit_Count <= 3'b111;
    end
    else
    begin
      o_RX_DV   <= 1'b0;

      if (o_TX_Ready)
      begin
        r_RX_Bit_Count <= 3'b111;
      end
      else if ((r_Leading_Edge & ~w_CPHA) | (r_Trailing_Edge & w_CPHA))
      begin
        o_RX_Byte[r_RX_Bit_Count] <= i_SPI_MISO;
        r_RX_Bit_Count            <= r_RX_Bit_Count - 1'b1;
        if (r_RX_Bit_Count == 3'b000)
        begin
          o_RX_DV   <= 1'b1;
        end
      end
    end
  end
  
  // Adding clock delay to signals for alignment.
  always @(posedge i_Clk or negedge i_Rst_L)
  begin
    if (~i_Rst_L)
    begin
      o_SPI_Clk  <= w_CPOL;
    end
    else
      begin
        o_SPI_Clk <= r_SPI_Clk;
      end // else: !if(~i_Rst_L)
  end // always @ (posedge i_Clk or negedge i_Rst_L)
endmodule // SPI_Master

