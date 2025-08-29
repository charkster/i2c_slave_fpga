
module i2c_slave_top (
  input logic clk,      // board clock, this should be faster than SCL
  input logic button_0, // button closest to PMOD connector
  input logic scl,
  inout wire  sda
);

  logic rst_n;
  logic sda_out;
  logic sda_in;
  
  logic [7:0] addr;
  logic [7:0] wdata;
  logic [7:0] rdata;
  logic       wr_en_wdata;
  logic       wr_en_wdata_sync;
  logic [1:0] sda_shift;
  
  assign sda_in = sda; // this is for read-ablity

  logic rst_i2c_n; // optional to reset i2c_slave if sda is stuck low
  
  // button_0 is high when pressed
  synchronizer u_synchronous_rst_n
  ( .clk,                   // input
    .rst_n    (~button_0),  // input
    .data_in  (1'b1),       // input
    .data_out (rst_n)       // output
  );
    
  bidir u_sda
  ( .pad    ( sda ),     // inout
    .to_pad ( sda_out ), // input
    .oe     ( ~sda_out)  // input, open drain
  );

  i2c_slave 
  # ( .SLAVE_ID(7'h24) )
  u_i2c_slave
  ( .rst_n (rst_n & rst_i2c_n), // input 
    .scl,                       // input 
    .sda_in,                    // input 
    .sda_out,                   // output  
    .i2c_active          ( ),   // output 
    .rd_en               ( ),   // output
    .wr_en               ( ),   // output
    .rdata,                     // input [7:0]
    .addr,                      // output [7:0]
    .wdata,                     // output [7:0]
    .wr_en_wdata                // output
  );
  
  synchronizer u_wr_en_sync
  ( .clk,                        // input
    .rst_n    (rst_n),           // input
    .data_in  (wr_en_wdata),     // input
    .data_out (wr_en_wdata_sync) // output
  );

  reg_map u_reg_map
  ( .clk,                     // input
    .rst_n,                   // input
    .addr,                    // input [7:0], data is stable when used
    .wdata,                   // input [7:0], data is stable when used
    .wr_en_wdata (wr_en_wdata_sync), // input
    .rdata,                   // output [7:0]
    .register_0 ( ),          // output [7:0]
    .register_1 ( ),          // output [7:0]
    .register_2 ( ),          // output [7:0]
    .register_3 ( )           // output [7:0]
  );

  ///// This logic is optional, to reset i2c_slave in case sda is stuck low
  logic        sda_out_sync;
  logic [15:0] inactive_count;

  synchronizer u_sda_out_sync
  ( .clk,                   // input
   .rst_n    (rst_n),       // input
   .data_in  (sda_out),     // input
   .data_out (sda_out_sync) // output
  );

  always_ff @(posedge clk, negedge rst_n)
    if (~rst_n)                    inactive_count <= 'd0;
    else if (sda_out_sync == 1'b0) inactive_count <= inactive_count + 'd1;
    else                           inactive_count <= 'd0

  always_ff @(posedge clk, negedge rst_n)
    if (~rst_n)                       rst_i2c_n <= 1'b1;
  else if (inactive_count == 'd32000) rst_i2c_n <= 1'b0; // this value is dependent on the FPGA board clock, duration should be 1ms or a bit more
endmodule
