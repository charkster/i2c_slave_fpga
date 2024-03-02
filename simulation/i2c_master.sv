
//`timescale 1ns/100ps
module i2c_master
  #( parameter value   = "FAST",
     parameter scl_min = "HIGH" )
   ( inout  sda,
     output scl
    );

   integer scl_period;
   integer scl_min_time_high;   // minimum time that SCL is high
   integer scl_min_time_low;    // minimum time that SCL is low

   reg [31:0] instruction;      // Instruction being executed.

   reg        data_bit;
   reg [7:0]  rx_data_byte;
   reg [7:0]  reg_addr;
   reg [6:0]  dev_addr;

   wire       sda_to_master;
   reg        sda_from_master;
   reg        scl_from_master;
   reg        enable_pull_up;
   integer    verbosity;

   // add these to simulation waveforms for I2C status
   reg [(256*8)-1:0] mstr;
   reg [(256*8)-1:0] error_msg;
   
   // Runtime versions of value/scl_min
   reg [(256*8)-1:0] i2c_mode_i;
   reg [(256*8)-1:0] scl_min_i;

   // I2S High Speed (Hs) Enable
   integer bus_cap = 100; //pF Capacitance
   
   // Flag for assertion to monitor highspeed
   reg sending_hs_master_code = 0;
   reg sending_start          = 0;
   reg high_speed             = 0;

   /////////////////////////////////////////////////// Tasks for initialization of I2C Master ///

   // Set I2C Mode
   // STANDARD
   // FAST
   // FAST_PLUS
   task set_i2c_mode;
     input [10*8-1:0] mode;
     begin
        i2c_mode_i = mode ;
        scl_timing;
     end
   endtask
  
   // Set I2C SCL Corner
   // HIGH
   // LOW
   task set_scl_min;
     input [10*8-1:0] mode;
     begin
        scl_min_i = mode ;
     end
   endtask
     
   //Manually set timing
   task set_scl_timing;
     input integer high;
     input integer low;
     begin
       scl_min_time_high = high;
       scl_min_time_low  = low;
     end
   endtask

   task scl_timing;
     begin
       //Spec Speeds
       case (i2c_mode_i)
         "STANDARD" : begin
           scl_period        = 10000;
           scl_min_time_high = 4000;
           scl_min_time_low  = 4700;
         end
         "FAST" : begin 
           scl_period        = 2500;
           scl_min_time_high = 600;
           scl_min_time_low  = 1300;
         end
         "FAST_PLUS" : begin
           scl_period        = 1000;
           scl_min_time_high = 260;
           scl_min_time_low  = 500;
         end
         default : begin
           $sformat(mstr,"I2C not set to accepted code ; %s", i2c_mode_i);
         end
       endcase
         
       // 3.4 MHz 
       if (high_speed) begin
           scl_period        =  294;
           scl_min_time_high =  60;
           scl_min_time_low  =  160;
       end
         
       if (scl_min_i == "LOW") begin
           scl_min_time_high = scl_period - scl_min_time_low;
       end
       else begin
           scl_min_time_low = scl_period - scl_min_time_high;
       end
         
     end
   endtask

   task i2c_ena;
      input val;

      begin
         idle;
         if(val == 1'b1)begin
           do_pull_up_enable;
         end
         else begin
           do_pull_up_disable;
         end
      end
   endtask // i2c_ena

   task do_pull_up_disable;
      begin
         enable_pull_up = 0;
      end
   endtask
   
   task do_pull_up_enable;
      begin
         enable_pull_up = 1;
      end
   endtask

   task set_verbosity_level;
      input integer val;

      begin
         verbosity = val;
      end
   endtask

   ////////////////////////////////////////////////////////////////////////////// INITAL STATEMENT ///////
   // Take default timing values
   initial begin
     set_i2c_mode  ( value   );
     set_scl_min   ( scl_min );
     set_verbosity_level(2);
     scl_timing;
     i2c_ena       ( 0       );
   end

   assign (weak1,strong0) scl = (scl_from_master == 1'b0) ? 1'b0 : 1'bz ;
 
   // resistive pull up to emulate the pull up on the board
   assign (pull1,pull0  ) scl = (enable_pull_up == 1) ? 1'b1 : 1'bz;
   
   // resistive pull up to emulate the pull up on the board
   assign (pull1,pull0  ) sda = (enable_pull_up == 1) ? 1'b1 : 1'bz;

   assign sda_to_master = sda ;
   assign (weak1,strong0) sda  = (sda_from_master == 1'b0) ? 1'b0 : 1'bz;
 
   //////////////////////////////////////////////////////////////////////////// Functional I2C Tasks ///////

   task i2c_hs_seq;
     reg   [7:0] hs_mode_id;
     reg   [1:0] random_id;
     begin
         random_id  = $random() ;
         hs_mode_id = {5'b0000_1, random_id} ;
         STA;
         AWR( hs_mode_id);
         //I2C Rev 4 Section 5.3.2 This will give error if no hs-devices (no ACK)
         sending_hs_master_code = 1'b1;
         SnACK;
         sending_hs_master_code = 1'b0;
         high_speed = 1'b1;
         scl_timing;
       end
   endtask

   task i2c_devaddr_write;
      input [6:0] i2c_slave_addr;

      begin
         if(verbosity > 1)begin
            $sformat(mstr,"Wr DevID %0h",i2c_slave_addr);
         end
         STA;
         AWR(i2c_slave_addr);
         SACK; // should be SNACK once that exists
      end
   endtask

   task i2c_write_data;
      input [7:0] data;
      input       stop;
      begin
         reg_addr = reg_addr+1;
         if(verbosity > 1)begin
            $sformat(mstr,"Wr DevID %0h addr %0h data %0h",dev_addr,reg_addr,data);
         end
         DWR(data);
         SACK;
         if (stop) STO;
       end
    endtask
     
   task i2c_write_no_stop;
      input [6:0] i2c_slave_addr;
      input [7:0] addr;
      input [7:0] data;
      begin
         if(verbosity > 1)begin
            $sformat(mstr,"Wr DevID %0h addr %0h data %0h",i2c_slave_addr,addr,data);
         end
         STA;
         AWR(i2c_slave_addr);
         SACK;
         RAD(addr);
         SACK;
         DWR(data);
         SACK;
       end
   endtask
     
   task i2c_write;
      input [6:0] i2c_slave_addr;
      input [7:0] addr;
      input [7:0] data;
      begin
         i2c_write_no_stop(i2c_slave_addr, addr, data);
         STO;
       end
   endtask
   
   task i2c_write_word; // LSB first
      input [6:0] i2c_slave_addr;
      input [7:0] addr;
      input [15:0] data;
      begin
         i2c_write_no_stop(i2c_slave_addr, addr, data[7:0]);
         i2c_write_data(data[15:8],1'b1);
       end
   endtask
     
   task i2c_hs_write_no_stop;
      input [6:0] i2c_slave_addr;
      input [7:0] addr;
      input [7:0] data;
      begin
         i2c_hs_seq;
         i2c_write_no_stop(i2c_slave_addr, addr, data);
       end
   endtask

   task i2c_hs_write;
      input [6:0] i2c_slave_addr;
      input [7:0] addr;
      input [7:0] data;
      begin
         i2c_hs_write_no_stop(i2c_slave_addr, addr, data);
         STO;
       end
   endtask

   // Checks for NO ACKS.
   // Intended to check that when device id
   // is incorrect there is no response
   task i2c_write_no_slave;
      input [6:0] i2c_slave_addr;
      input [7:0] addr;
      input [7:0] data;

      begin
         if(verbosity > 1)begin
            $sformat(mstr,"Wr DevID %0h addr %0h data %0h",i2c_slave_addr,addr,data);
         end
         STA;
         AWR(i2c_slave_addr);
         SnACK;
         RAD(addr);
         SnACK;
         DWR(data);
         SnACK;
         STO;
      end
   endtask // i2c_write

   task i2c_read_no_stop;
      input  [6:0] i2c_slave_addr;
      input  [7:0] addr;
      output [7:0] data;
      
      begin
         STA;
         AWR(i2c_slave_addr);
         SACK;
         RAD(addr);
         SACK;
         STA;
         ARD(i2c_slave_addr);
         SACK;
         DGT(data);
         if(verbosity > 1)begin
            $sformat(mstr,"Rd DevID %0h addr %0h data %0h",i2c_slave_addr,addr,data);
         end
      end
   endtask

   task i2c_read;
      input  [6:0] i2c_slave_addr;
      input  [7:0] addr;
      output [7:0] data;
      
      begin
         i2c_read_no_stop(i2c_slave_addr, addr, data);
         MnACK;
         STO;
      end
   endtask
   
   task i2c_read_word;
      input  [6:0] i2c_slave_addr;
      input  [7:0] addr;
      output [15:0] data;
      
      begin
         i2c_read_no_stop(i2c_slave_addr, addr, data[7:0]);
         MACK;
         DGT(data[15:8]);
         MnACK;
         STO;
      end
   endtask

   task i2c_hs_read_no_stop;
      input  [6:0] i2c_slave_addr;
      input  [7:0] addr;
      output [7:0] data;
     
      begin
         i2c_hs_seq;
         i2c_read_no_stop(i2c_slave_addr, addr, data);
         MACK;
      end
   endtask

   task i2c_hs_read;
      input  [6:0] i2c_slave_addr;
      input  [7:0] addr;
      output [7:0] data;
      input        stop;
     
      begin
         i2c_hs_seq;
         i2c_read_no_stop(i2c_slave_addr, addr, data);
         MnACK;
         STO;
      end
   endtask

   // read-modify-write
   task i2c_bf_write;
     input [6:0] i2c_slave_addr;
     input [7:0] addr;      // address
     input [7:0] bit_value; // bitfield value
     input [7:0] offset;    // offset to bitfield
     input [7:0] width;     // width of bitfield
     logic [7:0] bit_mask;
     logic [7:0] mod_val;
     logic [7:0] read_data;
     begin
       i2c_read (i2c_slave_addr, addr, read_data);
       bit_mask = (2 ** width - 1) << offset;
       mod_val = (read_data & (~bit_mask)) + (bit_value << offset);
       i2c_write(i2c_slave_addr, addr, mod_val);
     end
   endtask


   //
   // Routine to put SDA & SCL idle
   //
   // Usage: idle;
   //
   task idle;
      begin
         instruction       <= "NULL";
         sda_from_master   <= 1;
         scl_from_master   <= 1;
         data_bit          <= 0;
         rx_data_byte      <= 0;
      end
   endtask

   //
   // Routine to send a data bit from master to slave
   //
   // Usage: tx_data_bit(data_bit);
   //
   task tx_data_bit;
      input bitt;
      begin
         sda_from_master <= bitt;
         scl_from_master <= 0;
         #(scl_min_time_low/2)
         sda_from_master <= bitt;
         scl_from_master <= 1;
         #(scl_min_time_high/2)
         sda_from_master <= bitt;
         scl_from_master <= 1;
         #(scl_min_time_high/2)
         sda_from_master <= bitt;
         scl_from_master <= 0;
         #(scl_min_time_low/2)
         sda_from_master <= bitt;
         scl_from_master <= 0;
      end
   endtask

   //
   // Routine to receive a Data bit at the master
   //
   // Usage: rx_data_bit;
   //
   task rx_data_bit;
      begin
         sda_from_master <= 1;
         scl_from_master <= 0;
         #(scl_min_time_low/2)

         scl_from_master <= 1;
         #(scl_min_time_high/2)
         scl_from_master <= 1;
         #(scl_min_time_high/2)
         data_bit        <= sda_to_master;
         scl_from_master <= 0;
         #(scl_min_time_low/2)
         scl_from_master <= 0;
      end
   endtask

   task random_clocks;
      begin
         scl_from_master <= 1;
         #(scl_min_time_high/2)
         scl_from_master <= 0;
         #(scl_min_time_low/2)
         scl_from_master <= 0;
         #(scl_min_time_low/2)
         scl_from_master <= 1;
         #(scl_min_time_high/2)
         scl_from_master <= 1;
      end
   endtask

   //
   // Routine to send a START condition from master to slave
   //
   // Usage: STA;
   //
   task STA;
      begin
        fork 
          begin : sda_released
            if (sda == 0) begin
              if(verbosity > 1)begin
                 $sformat(mstr,"Waiting for SDA to be released");
              end
              @(posedge sda) ;
            end
            #1ns ;
            disable sda_timeout;
          end
          begin : sda_timeout
            #100ms;
            $sformat(error_msg, "Master timeout while waiting for SDA to be released");
            disable sda_released;
          end
        join

         instruction     <= "STA ";
         sda_from_master <= 1;
         #(scl_min_time_low/2)
         sda_from_master <= 1;
         scl_from_master <= 1;
         #(scl_min_time_high/2)
         
         sending_start    = 1;
         
         sda_from_master <= 0;
         scl_from_master <= 1;
         #(scl_min_time_high/2)

         sending_start    = 0;
         
         sda_from_master <= 0;
         scl_from_master <= 0;
         #(scl_min_time_low/2) 
         sda_from_master <= 0;
         scl_from_master <= 0;
         instruction     <= "NULL";
      end
   endtask

   //
   // Routine to send a STOP condition from master to slave
   //
   // Usage: STO;
   //
   task STO;
      begin
         instruction     <= "STO ";
         sda_from_master <= 0;
         scl_from_master <= 0;
         #(scl_min_time_low/2)
         sda_from_master <= 0;
         scl_from_master <= 1;
         #(scl_min_time_high/2)
         sda_from_master <= 1;
         scl_from_master <= 1;
         #(scl_min_time_high/2)
         sda_from_master <= 1;
         #(scl_min_time_low/2)
         sda_from_master <= 1;
         #(scl_min_time_low/2)
         scl_from_master <= 1;
         instruction     <= "NULL";
         
         high_speed       = 0;
         scl_timing;
      end
   endtask

   //
   // Routine to send ACK from master to slave
   //
   // Usage: MACK
   //
   task MACK;
      begin
         instruction     <= "MACK";
         sda_from_master <= 0;
         scl_from_master <= 0;
         #(scl_min_time_low/2)
         scl_from_master <= 1;
         #(scl_min_time_high/2)
         scl_from_master <= 1;
         #(scl_min_time_high/2)
         scl_from_master <= 0;
         #(scl_min_time_low/2)
         scl_from_master <= 0;
         sda_from_master <= 1;
         instruction     <= "NULL";
      end
   endtask

   //
   // Routine to send NACK from master to slave
   //
   // Usage: MnACK
   //
   task MnACK;
      begin        
         instruction     <= "MnACK";      
         sda_from_master <= 1;           
         scl_from_master <= 0;           
         #(scl_min_time_low/2)           
         scl_from_master <= 1;           
         #(scl_min_time_high/2)          
         scl_from_master <= 1;           
         #(scl_min_time_high/2)          
         scl_from_master <= 0;           
         #(scl_min_time_low/2)           
         scl_from_master <= 0;           
         sda_from_master <= 1;           
         instruction     <= "NULL";      
      end                                 
   endtask

   //
   // Routine for master to wait for ACK from slave
   //
   // Usage: SACK
   //
   task SACK;
      begin
         instruction     <= "SACK";
         // Send a 1 on SDA to prove that the slave forces a 0 back
         sda_from_master <= 1;
         scl_from_master <= 0;
         #(scl_min_time_low/2);

         scl_from_master <= 1;
         // Checking for ACKs, the test bench used to hang
         if (sda_to_master != 0) begin
             $sformat(error_msg, "NO ACK received from slave");
         end
        
         #(scl_min_time_high/2)
         scl_from_master <= 1;
         #(scl_min_time_high/2)
         scl_from_master <= 0;
         #(scl_min_time_low/2)
         scl_from_master <= 0;
         instruction     <= "NULL";
      end
   endtask

   //
   // Routine for master to wait for nACK from slave
   //
   // Usage: SnACK
   //
   task SnACK;
      begin
         instruction     <= "SnACK";
         // Send a 1 on SDA to prove that the slave forces a 0 back
         sda_from_master <= 1;
         scl_from_master <= 0;

         #(scl_min_time_low/2);

         scl_from_master <= 1;
         // Checking for ACKs, the test bench used to hang
         if (sda_to_master != 1) begin
             $sformat(error_msg, "ACK received from slave");
         end
        
         #(scl_min_time_high/2)
         scl_from_master <= 1;
         #(scl_min_time_high/2)
         scl_from_master <= 0;
         #(scl_min_time_low/2)
         scl_from_master <= 0;
         instruction     <= "NULL";
      end
   endtask

   //
   // Routine to send address from master to slave
   //
   // Usage: ARD
   //
   task ARD;
      input [6:0] addr;
      begin
         instruction <= "ARD ";
         tx_data_bit(addr[6]);
         tx_data_bit(addr[5]);
         tx_data_bit(addr[4]);
         tx_data_bit(addr[3]);
         tx_data_bit(addr[2]);
         tx_data_bit(addr[1]);
         tx_data_bit(addr[0]);
         tx_data_bit(1'b1);
         instruction <= "NULL";
      end
   endtask

   //
   // Routine to send address from master to slave
   //
   // Usage: AWR
   //
   task AWR;
      input [6:0] addr;
      begin
         instruction <= "AWR ";
         tx_data_bit(addr[6]);
         tx_data_bit(addr[5]);
         tx_data_bit(addr[4]);
         tx_data_bit(addr[3]);
         tx_data_bit(addr[2]);
         tx_data_bit(addr[1]);
         tx_data_bit(addr[0]);
         tx_data_bit(1'b0);
         instruction <= "NULL";
         dev_addr = addr;
      end
   endtask

   //
   // Routine to send data byte from master to slave
   //
   // Usage: RAD(data);
   //
   task RAD;
      input [7:0] data;
      begin
         instruction <= "RAD ";
         tx_data_bit(data[7]);
         tx_data_bit(data[6]);
         tx_data_bit(data[5]);
         tx_data_bit(data[4]);
         tx_data_bit(data[3]);
         tx_data_bit(data[2]);
         tx_data_bit(data[1]);
         tx_data_bit(data[0]);
         instruction <= "NULL";
         reg_addr = data;
      end
   endtask

   //
   // Routine to send data byte from master to slave
   //
   // Usage: DWR(data);
   //
   task DWR;
      input [7:0] data;
      begin
         instruction <= "DWR ";
         tx_data_bit(data[7]);
         tx_data_bit(data[6]);
         tx_data_bit(data[5]);
         tx_data_bit(data[4]);
         tx_data_bit(data[3]);
         tx_data_bit(data[2]);
         tx_data_bit(data[1]);
         tx_data_bit(data[0]);
         instruction <= "NULL";
      end
   endtask

   //
   // Routine to receive data byte at master
   //
   // Usage: DRD;
   //
   task DRD;
      input [7:0] exp_data;
      begin
         instruction <= "DRD ";
         rx_data_bit;
         rx_data_byte[7] = data_bit;
         rx_data_bit;
         rx_data_byte[6] = data_bit;
         rx_data_bit;
         rx_data_byte[5] = data_bit;
         rx_data_bit;
         rx_data_byte[4] = data_bit;
         rx_data_bit;
         rx_data_byte[3] = data_bit;
         rx_data_bit;
         rx_data_byte[2] = data_bit;
         rx_data_bit;
         rx_data_byte[1] = data_bit;
         rx_data_bit;
         rx_data_byte[0] = data_bit;
         instruction = "NULL";
         
         $sformat(mstr,"Read  Addr : %02X, Read : %02X, Exp : %02X", reg_addr, rx_data_byte, exp_data);
      end
   endtask

   //
   // Routine to receive data byte at master
   //
   // Usage: DRD;
   //
   task DGT;
      output [7:0] exp_data;
      begin
         instruction <= "DRD ";
         rx_data_bit;
         rx_data_byte[7] = data_bit;
         rx_data_bit;
         rx_data_byte[6] = data_bit;
         rx_data_bit;
         rx_data_byte[5] = data_bit;
         rx_data_bit;
         rx_data_byte[4] = data_bit;
         rx_data_bit;
         rx_data_byte[3] = data_bit;
         rx_data_bit;
         rx_data_byte[2] = data_bit;
         rx_data_bit;
         rx_data_byte[1] = data_bit;
         rx_data_bit;
         rx_data_byte[0] = data_bit;
         instruction = "NULL";
         exp_data = rx_data_byte;
      end
   endtask

endmodule
