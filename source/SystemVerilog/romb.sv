module romb
#(parameter DATA_WIDTH=8, 
parameter ARRAY_W=4, 
parameter ARRAY_L=4)
(	input clk,
    output reg [0:ARRAY_W-1] [0:ARRAY_L-1] [DATA_WIDTH - 1:0] data_rom
);

genvar i, j;
reg [DATA_WIDTH-1:0] rom [ARRAY_W*ARRAY_L-1:0];
//wire [DATA_WIDTH*SIZE-1:0] rom_wire;
wire [0:ARRAY_W-1] [0:ARRAY_L-1] [DATA_WIDTH - 1:0] rom_wire;
initial begin
    $readmemh ("b_data.hex", rom);
end

//generate
//    for (t=0;t<SIZE;t=t+1) begin: generate_roma
//        assign rom_wire[DATA_WIDTH*t +: DATA_WIDTH] = rom[t];
//    end
//endgenerate

generate
    for (i=0;i<ARRAY_W;i=i+1) begin: generate_roma_W
        for (j=0;j<ARRAY_L;j=j+1) begin: generate_roma_L
	        assign rom_wire[i][j] = rom[ARRAY_L*i + j];
	    end
    end
endgenerate

always @(posedge clk) 
begin 
    data_rom <= rom_wire;
end
endmodule
