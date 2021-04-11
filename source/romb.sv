module romb
#(parameter DATA_WIDTH=8, 
parameter SIZE=16)
(input clk,
    output reg [DATA_WIDTH*SIZE-1:0] data_rom);
genvar t;
reg [DATA_WIDTH-1:0] rom [SIZE-1:0];
wire [DATA_WIDTH*SIZE-1:0] rom_wire;
initial begin
    $readmemh ("../b_data.hex", rom);
end
generate
    for (t=0;t<SIZE;t=t+1) begin: generate_roma
        assign rom_wire[DATA_WIDTH*t +: DATA_WIDTH] = rom[t];
    end
endgenerate
always @(posedge clk) 
begin 
    data_rom <= rom_wire;
end
endmodule
