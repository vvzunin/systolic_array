//`timescale 1 ns / 100 ps

module testbench_sys_array_fetcher
#(
	parameter DATA_WIDTH=8,
	parameter ARRAY_W=5, //i
	parameter ARRAY_L=2);//j
	
reg clk, reset_n, load_params, start_comp;
reg [0:ARRAY_W-1] [0:ARRAY_L-1] [DATA_WIDTH-1:0] input_data_a;
reg [0:ARRAY_W-1] [0:ARRAY_L-1] [DATA_WIDTH-1:0] input_data_b; 

wire ready;
wire [0:ARRAY_W-1] [0:ARRAY_W-1] [2*DATA_WIDTH-1:0] out_data;
	 

sys_array_fetcher 
#(.DATA_WIDTH(DATA_WIDTH), 
	.ARRAY_W(ARRAY_W), 
	.ARRAY_L(ARRAY_L)) 
sys_array_fetcher0 (
	.clk(clk),
	.reset_n(reset_n),
	.load_params(load_params),
  .start_comp(start_comp),
  .input_data_a(input_data_a),
  .input_data_b(input_data_b),
  .ready(ready),
  .out_data(out_data)
);

initial $dumpvars;
initial begin
    clk = 0;
    forever #10 clk=!clk;
end

integer i, j;

initial
    begin
      reset_n=0; load_params = 0;
      #80; reset_n=1;
      #20;
      load_params = 1'b1;
		  
		  for (i=0;i<ARRAY_W;i=i+1) begin
        for (j=0;j<ARRAY_L;j=j+1) begin
            input_data_a[i][j] = ARRAY_L*i + j + 1;
        end
      end
		  for (i=0;i<ARRAY_W;i=i+1) begin
        for (j=0;j<ARRAY_L;j=j+1) begin
            input_data_b[i][j] = ARRAY_L*i + j + 1;
        end
      end
		  #20;
		  load_params = 1'b0;
		  #10;
		  start_comp = 1'b1;
		  #20;
		  start_comp = 1'b0;
		  
    end
endmodule
