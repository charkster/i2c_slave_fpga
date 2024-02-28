module tb_i2c_top ();

   parameter EXT_CLK_PERIOD_NS = 100;
   
   reg         clk;
   reg         reset;

   initial begin
      clk = 1'b0;
      forever
        #(EXT_CLK_PERIOD_NS/2) clk = ~clk;
   end

   //----------
   // I2C
   //----------
   wire sda;
   wire scl;

   pullup(sda);
   pullup(scl);

   // I2C Master instance
   i2c_master
      #( .value   ( "FAST" ),  // 400MHz
         .scl_min ( "HIGH" ) ) // this is the most aggressive
   u_mstr_i2c
     ( .sda       ( sda ), // inout
       .scl       ( scl )  // output
     );

   logic  [7:0] i2c_read_data;
   logic [15:0] i2c_read_word;

   initial begin
      #EXT_CLK_PERIOD_NS;
      reset = 1'b1;
      #EXT_CLK_PERIOD_NS;
      reset = 1'b0;
      repeat(100) #EXT_CLK_PERIOD_NS;
      u_mstr_i2c.i2c_read (7'h24, 8'h8F, i2c_read_data);
      u_mstr_i2c.i2c_write(7'h24, 8'h03, 8'h7B);
      u_mstr_i2c.i2c_write(7'h24, 8'h02, 8'h3A);
      u_mstr_i2c.i2c_write_word(7'h24, 8'h00, 16'hCB04);
      u_mstr_i2c.i2c_read_word(7'h24, 8'h00, i2c_read_word);
      u_mstr_i2c.i2c_read (7'h24, 8'h03, i2c_read_data);
      u_mstr_i2c.i2c_write(7'h98, 8'h82, 8'h7A);
      u_mstr_i2c.i2c_read (7'hA3, 8'h03, i2c_read_data);
      u_mstr_i2c.i2c_read_word(7'h24, 8'h02, i2c_read_word);
	  repeat(100) #EXT_CLK_PERIOD_NS;
      $finish;
   end

   i2c_slave_top u_i2c_slave_top
     ( .clk,                      // input  
       .button_0   ( reset     ), // input  
       .scl	       ( scl       ), // input  
       .sda	       ( sda       )  // inout  
       );


endmodule
