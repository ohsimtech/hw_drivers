/**
	Module name: driver_ad5328
	Author: P.Trujillo
	Date: Nov24
	Description: Driver for 8 channel, 12-bit DAC AD5328
	History:
		- 1.0: Module created
**/

module driver_ad5328 #(
  parameter TRANSACTION_DELAY = 100
)(
	input wire aclk,
	input wire resetn,

	/* Analog output channels */
  input signed [11:0] ch0_data,
  input signed [11:0] ch1_data,
  input signed [11:0] ch2_data,
  input signed [11:0] ch3_data,
  input signed [11:0] ch4_data,
  input signed [11:0] ch5_data,
  input signed [11:0] ch6_data,
  input signed [11:0] ch7_data,

	/* SPI interface */
	output reg dac_dout,
	output reg dac_ldac,
	output reg dac_sync,
	output reg dac_sclk
);

  /* comm delay after reset release */
  localparam INITIAL_CLK_DELAY = 100;
  localparam INITIAL_CLK_DELAY_WIDTH = $clog2(INITIAL_CLK_DELAY);

	localparam TRANSACTION_DELAY_WIDTH = $clog2(TRANSACTION_DELAY);

	localparam MAX_INDEX_CONFIG_PARAM = 1;
	localparam MAX_INDEX_DATA_PARAM = 7;

	localparam WRITE_LDAC_REGISTER = {3'b101, 11'd0, 2'b00};

	/* spi comm signals */
	reg [1:0] r_spi_state;
	reg [15:0] r_spi_data_send;
	reg [3:0] r_spi_data_index;
	reg [TRANSACTION_DELAY_WIDTH-1:0] r_spi_transaction_delay_counter;
	wire w_spi_busy;

	/* DAC controller signals */
	reg [INITIAL_CLK_DELAY_WIDTH-1:0] r_dac_controller_initial_delay;
	reg r_dac_controller_begin_transaction;
	reg [2:0] r_dac_controller_state;
	reg [15:0] r_dac_controller_data_send;
	reg [2:0] r_counter_config_registers;
	reg [2:0] r_counter_data_registers;
	wire [15:0] r_dac_controller_config_register_matrix [1:0];
	wire [15:0] r_dac_controller_data_register_matrix [7:0];
	
	/* DAC controller */
	assign r_dac_controller_config_register_matrix[0] = {3'b101, 11'd0, 2'b00};
	assign r_dac_controller_config_register_matrix[1] = {3'b101, 11'd0, 2'b00};

	assign r_dac_controller_data_register_matrix[0] = {1'b0, 3'b000, ch0_data};
	assign r_dac_controller_data_register_matrix[1] = {1'b0, 3'b001, ch1_data};
	assign r_dac_controller_data_register_matrix[2] = {1'b0, 3'b010, ch2_data};
	assign r_dac_controller_data_register_matrix[3] = {1'b0, 3'b011, ch3_data};
	assign r_dac_controller_data_register_matrix[4] = {1'b0, 3'b100, ch4_data};
	assign r_dac_controller_data_register_matrix[5] = {1'b0, 3'b101, ch5_data};
	assign r_dac_controller_data_register_matrix[6] = {1'b0, 3'b110, ch6_data};
	assign r_dac_controller_data_register_matrix[7] = {1'b0, 3'b111, ch7_data};
	
	always @(posedge aclk)
		if (!resetn) begin
			r_dac_controller_state <= 3'd0;
			r_dac_controller_data_send <= 16'd0;
			r_dac_controller_begin_transaction <= 1'b0;
			r_counter_config_registers <= 2'd0;
			r_counter_data_registers <= 2'd0;
			r_dac_controller_initial_delay <= {INITIAL_CLK_DELAY_WIDTH{1'b0}};
			dac_ldac <= 1'b1;
		end
		else 
			case (r_dac_controller_state)
				3'd0: begin
					if (r_dac_controller_initial_delay == INITIAL_CLK_DELAY) r_dac_controller_state <= 3'd1;
					else r_dac_controller_state <= 3'd0;
	
					r_dac_controller_data_send <= 16'd0;
					r_dac_controller_initial_delay <= r_dac_controller_initial_delay + 1;

				end
				3'd1: begin /* send config*/
					r_dac_controller_state <= 3'd2;

					r_dac_controller_begin_transaction <= 1'b1;
					r_dac_controller_data_send <= r_dac_controller_config_register_matrix[r_counter_config_registers];
					dac_ldac <= 1'b0;
				end	
				3'd2: begin
					if (!w_spi_busy && (r_counter_config_registers == MAX_INDEX_CONFIG_PARAM)) r_dac_controller_state <= 3'd3;
					else if (!w_spi_busy && (r_counter_config_registers < MAX_INDEX_CONFIG_PARAM)) r_dac_controller_state <= 3'd1;
					else r_dac_controller_state <= 3'd2;

					r_dac_controller_begin_transaction <= 1'b0;
					r_counter_config_registers <= (!w_spi_busy)? r_counter_config_registers+3'd1: r_counter_config_registers;
				end
				3'd3: begin /* send data*/
					if (w_spi_busy) r_dac_controller_state <= 3'd4;
					else r_dac_controller_state <= 3'd3;

					r_dac_controller_begin_transaction <= 1'b1;
					r_dac_controller_data_send <= r_dac_controller_data_register_matrix[r_counter_data_registers];
				end	
				3'd4: begin
					if (!w_spi_busy) r_dac_controller_state <= 3'd3;
					else r_dac_controller_state <= 3'd4;

					r_dac_controller_begin_transaction <= 1'b0;
					r_counter_data_registers <= (!w_spi_busy)? r_counter_data_registers+3'd1: r_counter_data_registers;
				end
			endcase

  /* SPI clk generator */
  /* spi clk works at aclk/2 */
  always @(posedge aclk)
    if (!resetn/* || dac_sync*/)// (r_spi_state == 2'd0) || (r_spi_state == 2'd3)) 
      dac_sclk <= 1'b0;
    else 
      dac_sclk <= ~dac_sclk;

	always @(posedge aclk)
		if (!resetn) begin
			r_spi_state <= 2'd0;
			r_spi_data_send <= 16'd0;
			r_spi_data_index <= 4'd15;
			r_spi_transaction_delay_counter <= {TRANSACTION_DELAY_WIDTH{1'b0}};
		end
		else
			case (r_spi_state)
				2'd0: begin
					if (r_dac_controller_begin_transaction && !dac_sclk) r_spi_state <= 2'd1;
					else r_spi_state <= 2'd0;

					r_spi_data_send <= r_dac_controller_data_send;
					r_spi_data_index <= 4'd15;
					r_spi_transaction_delay_counter <= {TRANSACTION_DELAY_WIDTH{1'b0}};
					dac_sync <= 1'b1;
				end
				2'd1: begin /* begin transaction */
					if (!dac_sync ) r_spi_state <= 2'd2;
          else r_spi_state <= 2'd1;
          
          dac_sync <= 1'b0;
					dac_dout <= r_spi_data_send[r_spi_data_index];
				end
        2'd2: begin /* transaction in progress */
          if (r_spi_data_index == 0) r_spi_state <= 2'd3;
          else r_spi_state <= 2'd2;

          r_spi_data_index <= dac_sclk? r_spi_data_index - 1: r_spi_data_index;
          dac_dout <= r_spi_data_send[r_spi_data_index];
          dac_sync <= 1'b0;
        end
				2'd3: begin
          if (r_spi_transaction_delay_counter >= TRANSACTION_DELAY) r_spi_state <= 2'd0;
          else r_spi_state <= 2'd3;

          r_spi_transaction_delay_counter <= r_spi_transaction_delay_counter + 1;
          dac_sync <= 1'b1;
				end
			endcase

	assign w_spi_busy = (r_spi_state != 2'd0)? 1'b1: 1'b0;


endmodule