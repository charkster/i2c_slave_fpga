
module bidir
  (
   inout wire pad,
   input wire to_pad,
   input wire oe
   );

   assign pad = (oe) ? to_pad : 1'bz;

endmodule
