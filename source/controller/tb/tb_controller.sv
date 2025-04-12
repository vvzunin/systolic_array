`timescale 1ns / 1ps
module tb_controller;
    /* Test bench specific parameters */
        localparam baud_rate = 9600;
        localparam sys_clk_freq = 50000000;

    /* Clock simulation */
        localparam CLK_PERIOD = 10;         // in nanoseconds
    
    /* General shortcuts */
        localparam T = 1'b1;
        localparam F = 1'b0;
        
//** SIGNAL DECLARATIONS **************************************
 
    /* UUT signals */
        reg clk;
        reg rstn;
        reg rx;
        wire tx;
        wire ready;
       
//** Clock ****************************************************     
 
    initial begin
        clk <= F;
        forever begin
            #(CLK_PERIOD / 2); clk <= ~ clk;
        end
    end

//** UUT Tests ************************************************ 

    initial begin
    
        $dumpvars();
        initial_conditions();
        reset_UUT();

        // FETCH_WEIGHTS
        send_byte(8'h55);
        send_byte(8'h02); 

        // WEIGHTS
        send_byte(8'h55);
        send_byte(8'h01);
        send_byte(8'h11);

        send_byte(8'h55);
        send_byte(8'h01);
        send_byte(8'h11);

        send_byte(8'h55);
        send_byte(8'h01);
        send_byte(8'h11);

        send_byte(8'h55);
        send_byte(8'h01);
        send_byte(8'h11);

        // LOAD WEIGHTS
        send_byte(8'h55);
        send_byte(8'h03);


        // DATA
        send_byte(8'h55);
        send_byte(8'h01);
        send_byte(8'h11);

        send_byte(8'h55);
        send_byte(8'h01);
        send_byte(8'h11);

        send_byte(8'h55);
        send_byte(8'h01);
        send_byte(8'h11);

        send_byte(8'h55);
        send_byte(8'h01);
        send_byte(8'h11);


        // START COMP
        send_byte(8'h55);
        send_byte(8'h04);

        wait(ready == 1'b1);
        
        $finish;
    end
    
    
//** Tasks **************************************************** 
    
    task initial_conditions(); begin
        repeat(5) @(posedge clk)
        rstn = T; 
        rx = T;
    end endtask  


    task reset_UUT(); begin
        @(posedge clk)
        rstn = F;
        @(posedge clk)
        rstn = T;
    end endtask  


    task delay(input integer N); begin
        repeat(N) @(posedge clk);
    end endtask  
    
    
    task send_byte (input reg[7:0] C); 
        reg [7:0] shift_reg;
    begin
        shift_reg = C;
        @(posedge clk)
        rx = F;                         // send start bit
        delay(sys_clk_freq / baud_rate);
            
        for(int i = 0; i < 8; i++) begin    // send serial data LSB first
            rx = shift_reg[0];
            shift_reg = shift_reg >> 1;
            delay(sys_clk_freq / baud_rate);
        end
        
        rx = T;                         // send stop bit
        delay(sys_clk_freq / baud_rate);
        
    end endtask
    
    task send_int (input reg[31:0] i); begin
        send_byte(8'h55); // start byte
        send_byte(8'h01); // cmd
        send_byte(i[7:0]); // data[0][0]
        send_byte(i[15:8]); // data[0][1]
        send_byte(i[23:16]); // data[0][2]
        send_byte(i[31:24]); // data[0][3]
    end endtask


//** INSTANTIATE THE UNIT UNDER TEST(UUT)**********************

    controller 
    controller_inst (
        .clk(clk),
        .rstn(rstn),
        .rx(rx),
        .tx(tx),
        .ready(ready)
    );


endmodule