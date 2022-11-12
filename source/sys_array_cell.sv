`include "defines.svh"

module sys_array_cell
#(parameter DATA_WIDTH = 8,
parameter TYPE = load)
(   input  clk,
    input  reset_n,
    input  param_load,
    input  signed [DATA_WIDTH - 1:0] input_data,
    input  signed [2*DATA_WIDTH-1:0] prop_data,
    input  signed [DATA_WIDTH-1:0] param_data,
	 
    output reg signed [2*DATA_WIDTH-1:0] out_data,
    output reg signed [DATA_WIDTH-1:0] prop_param
);

reg signed [DATA_WIDTH-1:0] param;

always @(posedge clk)
begin
	if (~reset_n) begin // reset
		out_data <= {2 * DATA_WIDTH{1'b0}};
		//param <= {DATA_WIDTH{1'b0}};
	end
	else if (param_load) begin // Загрузка параметров
		param <= param_data;
	end
	else begin // Вычисление
		out_data <= prop_data + input_data * (param ? TYPE == load : param_data);
		prop_param <= input_data;
	end
end
	
endmodule
