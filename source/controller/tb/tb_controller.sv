`timescale 1ns / 1ps
module tb_controller;
    localparam baud_rate = 9600;
    localparam sys_clk_freq = 50000000;

    localparam CLK_PERIOD = 10;  //ns

    localparam T = 1'b1;
    localparam F = 1'b0;

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
        send_byte(8'h55);
        send_byte(8'h02);

        //////////// SEND WEIGHTS  ////////////
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

        //////////// LOAD WEIGHTS  ////////////
        send_byte(8'h55);
        send_byte(8'h03);

        //////////// LOAD DATA     ////////////
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

        ////////// START COMP      ///////////
        send_byte(8'h55);
        send_byte(8'h04);

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
            delay(sys_clk_freq / baud_rate);

            for (int i = 0; i < 8; i++) begin  // send serial data LSB first
                rx = shift_reg[0];
                shift_reg = shift_reg >> 1;
                delay(sys_clk_freq / baud_rate);
            end

            rx = T;  // send stop bit
            delay(sys_clk_freq / baud_rate);

        end
    endtask

    controller dut (
        .clk(clk),
        .rstn(rstn),
        .rx(rx),
        .tx(tx),
        .ready(ready)
    );

endmodule
