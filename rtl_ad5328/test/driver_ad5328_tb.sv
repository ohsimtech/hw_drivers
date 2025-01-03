`timescale 1ns/1ns 

/* Time definitions */
`define _1us 1000
`define _100us 100000
`define _1ms 1000000
`define clkcycle 10


module driver_ad5328_tb();

	reg aclk;
	reg resetn;

	reg [11:0] r_ch0_data;
	reg [11:0] r_ch1_data;
	reg [11:0] r_ch2_data;
	reg [11:0] r_ch3_data;
	reg [11:0] r_ch4_data;
	reg [11:0] r_ch5_data;
	reg [11:0] r_ch6_data;
	reg [11:0] r_ch7_data;

	wire dac_dout;
	wire dac_ldac;
	wire dac_sync;
	wire dac_sclk;

  /* Fclk = 25 MHz, delay: 10 ns */
  initial begin
    aclk <= 1'b0;
    #(`clkcycle/2);
    forever begin
      #(`clkcycle/2);
      aclk <= ~aclk;
    end
  end

	driver_ad5328 #(
		.TRANSACTION_DELAY(3)
	) dut (
		.aclk(aclk),
		.resetn(resetn),
		/* Analog output channels */
		.ch0_data(r_ch0_data),
		.ch1_data(r_ch1_data),
		.ch2_data(r_ch2_data),
		.ch3_data(r_ch3_data),
		.ch4_data(r_ch4_data),
		.ch5_data(r_ch5_data),
		.ch6_data(r_ch6_data),
		.ch7_data(r_ch7_data),
		/* SPI interface */
		.dac_dout(dac_dout),
		.dac_ldac(dac_ldac),
		.dac_sync(dac_sync),
		.dac_sclk(dac_sclk)
	);

  initial begin

    /* VCD file generation */
    $dumpfile ("test_output.vcd");
    $dumpvars();

		r_ch0_data <= 12'd454;
		r_ch1_data <= 12'd454;
		r_ch2_data <= 12'd454;
		r_ch3_data <= 12'd454;
		r_ch4_data <= 12'd454;
		r_ch5_data <= 12'd454;
		r_ch6_data <= 12'd454;
		r_ch7_data <= 12'd454;

		resetn <= 1'b0;
		#(4*`clkcycle);
		resetn <= 1'b1;


		#(3*`_1ms);

		$finish();
	end

endmodule