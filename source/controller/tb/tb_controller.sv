`timescale 1ns / 1ps
`include "../uart_parser.svh"
module tb_controller;
    localparam CLK_PERIOD = 10;  //ns

    localparam T = 1'b1;
    localparam F = 1'b0;

    parameter DATA_WIDTH = 32, 
              MAX_LEN    = 256,
              ARRAY_W    = 10, 
              ARRAY_L    = 10, 
              ARRAY_A_W  = 4,  
              ARRAY_A_L  = 3,  
              ARRAY_W_W  = 3, 
              ARRAY_W_L  = 4,  
              BAUD_RATE  = 115200,
              W_DIGIT    = 4,
              CLK_FREQ   = 1_000_000_000 / CLK_PERIOD;

    reg  clk;
    reg  rstn;
    reg  rx;
    wire tx;
    wire ready;

    initial begin
        clk <= F;
        forever begin
            #(CLK_PERIOD / 2);
            clk <= ~clk;
        end
    end

    initial begin
        $dumpvars();
        initial_conditions();
        reset_DUT();

        //////////// FETCH WEIGHTS ////////////
        send_byte(`START_BYTE);
        send_byte(`CMD_FETCH_WEIGHTS);

        //////////// SEND WEIGHTS  ////////////
        repeat (ARRAY_W_L * ARRAY_W_W) send_int32(32'hffff_ffff);


        //////////// LOAD WEIGHTS  ////////////
        send_byte(`START_BYTE);
        send_byte(`CMD_LOAD_WEIGHTS);


        //////////// FETCH DATA    ////////////
        send_byte(`START_BYTE);
        send_byte(`CMD_FETCH_DATA);

        //////////// LOAD DATA     ////////////
        repeat (ARRAY_A_L * ARRAY_A_W) send_int32(32'hffff_ffff);

        ////////// START COMP      ///////////
        send_byte(`START_BYTE);
        send_byte(`CMD_START_COMP);

        wait (ready == 1'b1);

        $finish;
    end

    task initial_conditions();
        begin
            repeat (5) @(posedge clk) rstn = T;
            rx = T;
        end
    endtask

    task reset_DUT();
        begin
            @(posedge clk) rstn = F;
            @(posedge clk) rstn = T;
        end
    endtask


    task delay(input integer N);
        begin
            repeat (N) @(posedge clk);
        end
    endtask

    task send_byte(input reg [7:0] C);
        reg [7:0] shift_reg;
        begin
            shift_reg = C;
            @(posedge clk) rx = F;  // send start bit
            delay(CLK_FREQ / BAUD_RATE);

            for (int i = 0; i < 8; i++) begin  // send serial data LSB first
                rx = shift_reg[0];
                shift_reg = shift_reg >> 1;
                delay(CLK_FREQ / BAUD_RATE);
            end

            rx = T;  // send stop bit
            delay(CLK_FREQ / BAUD_RATE);

        end
    endtask

    task send_int32(input reg [31:0] C);
        for (int i = 0; i < 4; i++) begin
            send_byte(`START_BYTE);
            send_byte(`CMD_DATA);
            send_byte(C[i*8+:8]);
        end
    endtask

    controller #(
        .DATA_WIDTH(DATA_WIDTH),
        .ARRAY_W(ARRAY_W),
        .ARRAY_L(ARRAY_L),
        .ARRAY_W_W(ARRAY_W_W),
        .ARRAY_W_L(ARRAY_W_L),
        .ARRAY_A_W(ARRAY_A_W),
        .ARRAY_A_L(ARRAY_A_L),
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(clk),
        .rstn(rstn),
        .rx(rx),
        .tx(tx),
        .ready(ready)
    );

endmodule
