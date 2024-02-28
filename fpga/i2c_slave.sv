

module i2c_slave 
# ( parameter SLAVE_ID = 7'h24 )
( input  logic       rst_n,      // asynchronous active low reset
  input  logic       scl,        // sample on posedge, drive on negedge
  input  logic       sda_in,     // data in
  output logic       sda_out,    // data out
  // general purpose i2c slave outputs
  output logic       i2c_active, // High between a Start and Stop condition
  output logic       rd_en,      // Slave ID matched and current transfer is a read
  output logic       wr_en,      // Slave ID matched and current transfer is a write
  // regmap specific outputs
  input  logic [7:0] rdata,      // regmap read data
  output logic [7:0] addr,       // regmap read or write address
  output logic [7:0] wdata,      // regmap write data
  output logic       wr_en_wdata // wr_en when wdata is valid, it pulses
);

   localparam P_ACK  = 1'b0;     // I2C ACK
   localparam P_NACK = 1'b1;     // I2C NACK

   logic       start;
   logic       stop;
   logic [3:0] bit_cnt;
   logic       st_id_det;
   logic       rst_start_stop_n;
   logic       rst_stop_n;
   logic       idle;            
   logic       bit_cnt9;
   logic       valid_id;
   logic       rst_start_n;                 
   logic       start_tgl;
   logic       start_hold;
   logic [7:0] data_sr;
   logic       wdata_ready;
   logic       next_data_is_addr;
   logic       multi_cycle;

   always_ff @(negedge sda_in, negedge rst_n)
     if (!rst_n) start_tgl <= 1'b0;
     else        start_tgl <= start_tgl ^ scl;

   always_ff @(posedge scl, negedge rst_n)
     if (!rst_n) start_hold <= 1'b0;
     else        start_hold <= start_tgl;

   // falling SDA when SCL is high, cleaned up with flops
   assign start = start_tgl ^ start_hold;

   // combined reset and scl only used for STOP condition clearing
   assign rst_start_n = rst_n & scl;

   // STOP condition is rising edge of SDA when SCL is high
   always_ff @(posedge sda_in, negedge rst_start_n)
      if (!rst_start_n) stop <= 1'b0;
      else              stop <= 1'b1;

   assign rst_stop_n       = (rst_n & (~stop));
   assign rst_start_stop_n = (rst_n & (~start) & (~stop));

   always_ff @(posedge stop, negedge rst_n or posedge start)
      if (!rst_n)     i2c_active <= 1'b0;
      else if (start) i2c_active <= 1'b1;
      else            i2c_active <= 1'b0;

   assign bit_cnt9 = (bit_cnt == 4'd9);

   always_ff @(posedge scl, negedge rst_start_stop_n)
      if (!rst_start_stop_n) bit_cnt <= 4'd2; // extra cycle from delayed reset
      else if (idle)         bit_cnt <= 4'd0;
      else if (bit_cnt9)     bit_cnt <= 4'd1;
      else                   bit_cnt <= bit_cnt + 4'd1;

   always_ff @(posedge scl, negedge rst_stop_n, posedge start) 
      if (!rst_stop_n)   st_id_det <= 1'b0;
      else if (start)    st_id_det <= 1'b1;
      else if (bit_cnt9) st_id_det <= 1'b0;

   // Sets the write or read state flags depending on what is received during
   // the 8th data bit of the Slave ID field. Otherwise they reset if there is a NACK.
   always_ff @(posedge scl or negedge rst_start_stop_n)
      if (!rst_start_stop_n) begin
         wr_en  <= 1'b0;
         rd_en  <= 1'b0;
      end
      else if (bit_cnt9) begin
         if (sda_in == P_NACK) begin
            wr_en  <= 1'b0;
            rd_en  <= 1'b0;
         end
         else if (valid_id && st_id_det) begin
            wr_en <= ~data_sr[0];
            rd_en <=  data_sr[0];
         end
      end
   
   assign idle = (!st_id_det) && (!wr_en) && (!rd_en);

   // it is very important to check when the st_bit_cnt is equal to 8!!!!
   always_ff @(posedge scl, negedge rst_start_stop_n)
     if (!rst_start_stop_n)  valid_id <= 1'b0;
     else                    valid_id <= st_id_det && (bit_cnt == 4'd8) && (data_sr[6:0] == SLAVE_ID);

   always_ff @(posedge scl, negedge rst_n)
      if (!rst_n)                                                        data_sr <= 8'b0000_0000;
      else if ((data_sr[0] && valid_id) || (rd_en && (bit_cnt == 4'd9))) data_sr <= rdata;
      else                                                               data_sr <= {data_sr[6:0], sda_in};

   // Registered data out. It only outputs data whenever
   //   a) we ACK a correct Slave ID
   //   b) we ACK the receipt of a data byte
   //   b) we are in read mode and outputting data, except during the Master ACK/NACK
   always_ff @(negedge scl, negedge rst_n)
     if (!rst_n)                                 sda_out <= P_NACK;
     else if ( (bit_cnt9  && wr_en) || valid_id) sda_out <= P_ACK;
     else if ((!bit_cnt9) && rd_en)              sda_out <= data_sr[7];
     else                                        sda_out <= P_NACK;

  // THE FOLLOWING CODE IS NOT PART OF THE I2C_SLAVE, but is custom for the regmap
  // it is convenient to put it here, it assumes a single byte address
  // auto-incrementing address for multi-byte reads and writes.

  assign wdata_ready = wr_en && bit_cnt9;
   
   // the first data in a write cycle is the address, all following is write data
   always_ff @(posedge scl, negedge rst_n)
      if (!rst_n)           next_data_is_addr <= 1'b1;
      else if (start)       next_data_is_addr <= 1'b1; // clear when start is seen
      else if (wdata_ready) next_data_is_addr <= 1'b0;
   
   always_ff @(posedge scl, negedge rst_n)
      if (!rst_n)                                                    multi_cycle <= 1'b0;
      else if (start)                                                multi_cycle <= 1'b0;
      else if (rd_en || (wr_en && bit_cnt9 && (!next_data_is_addr))) multi_cycle <= 1'b1;
   
   // this pulse signals that wdata is stable
   always_ff @(posedge scl, negedge rst_n)
      if (!rst_n)           wr_en_wdata <= 1'b0;
      else                  wr_en_wdata <= wdata_ready && (~next_data_is_addr);
    
   always_ff @(posedge scl, negedge rst_n)
      if (!rst_n)                                addr <= 8'd0;
      else if (wdata_ready && next_data_is_addr) addr <= data_sr[7:0];
      else if ((bit_cnt == 4'd8) && multi_cycle) addr <= addr + 'd1;
   
   // 
   always_ff @(posedge scl, negedge rst_n)
      if (!rst_n)                                   wdata <= 8'd0;
      else if (wdata_ready && (!next_data_is_addr)) wdata <= data_sr[7:0];

endmodule