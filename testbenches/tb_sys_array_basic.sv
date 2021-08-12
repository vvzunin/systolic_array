`timescale 1 ns / 100 ps

module tb_sys_array_basic
#(
    parameter DATA_WIDTH = 8,
	parameter ARRAY_W_W = 4, //Строк в массиве весов
    parameter ARRAY_W_L = 4, //Столбцов в массиве весов
    parameter ARRAY_A_W = 4, //Строк в массиве данных
    parameter ARRAY_A_L = 4);//Столбцов в массиве данных
	
reg [0:ARRAY_W_W-1] [0:ARRAY_W_L-1] [DATA_WIDTH-1:0] parameters_test;
reg [0:ARRAY_A_L-1] [DATA_WIDTH-1:0] inputs_test;
wire [0:ARRAY_A_W-1] [2*DATA_WIDTH-1:0] outputs_test;
reg clk, reset_n, param_load;

sys_array_basic #(  .DATA_WIDTH(DATA_WIDTH), 
                    .ARRAY_W_W(ARRAY_W_W), .ARRAY_W_L(ARRAY_W_L),
                    .ARRAY_A_W(ARRAY_A_W), .ARRAY_A_L(ARRAY_A_L)) 
systolic_array(
	.clk(clk),
	.reset_n(reset_n),
	.weights_load(param_load),
	.weight_data(parameters_test),
	.input_data(inputs_test),
	.output_data(outputs_test)
);

initial $dumpvars;
initial begin
    clk = 0;
    forever #10 clk=!clk;
end

integer ii, jj;

initial
    begin
        reset_n=0; param_load = 0;
        #80; reset_n=1;
        #20;

        for (ii = 0; ii < ARRAY_W_W; ii = ii + 1) begin
            for (jj = 0; jj < ARRAY_W_L; jj = jj + 1) begin
                parameters_test[ii][jj] = ARRAY_W_L*ii + jj + 1;
            end
        end
        param_load = 1;
        #20; param_load = 0; #10; inputs_test[0] = 8'd1; //1st clk cycle
        #20; inputs_test[0] = 8'd5; inputs_test[1] = 8'd2; //2nd clk cycle
        #20; inputs_test[0] = 8'd9; inputs_test[1] = 8'd6; inputs_test[2] = 8'd3; //3rd clk cycle
        #20; inputs_test[0] = 8'd13; inputs_test[1] = 8'd10; inputs_test[2] = 8'd7; inputs_test[3] = 8'd4; //4th clock cycle
        #20; inputs_test[1] = 8'd14; inputs_test[2] = 8'd11; inputs_test[3] = 8'd8; //5th clock cycle
        #20; inputs_test[2] = 8'd15; inputs_test[3] = 8'd12; //6th clock cycle
        #20; inputs_test[3] = 8'd16; //7th clk cycle
        //#20; param_load = 0; #10; inputs_test[0] = 8'd1; //1st clk cycle
        //#20; inputs_test[0] = 8'd3; inputs_test[1] = 8'd2; //2nd clk cycle
        //#20; inputs_test[0] = 8'd5; inputs_test[1] = 8'd4; //3nd clk cycle
        //#20; inputs_test[0] = 8'd7; inputs_test[1] = 8'd6; //4nd clk cycle
        //#20; inputs_test[0] = 8'd9; inputs_test[1] = 8'd8; //5nd clk cycle
        //#20; inputs_test[1] = 8'd10; //6nd clk cycle
        #500; $finish;
    end
endmodule
