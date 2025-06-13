
// Documented Verilog UART
// Copyright (C) 2010 Timothy Goddard (tim@goddard.net.nz)
//               2013 Aaron Dahlen
// Distributed under the MIT licence.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

module uart #(
    parameter CLK_FREQ = 50_000_000,
    BAUD_RATE = 9600
) (
    input              clk,                 // The master clock for this module
    input              rstn,                // Synchronous reset
    input              rx,                  // Incoming serial line
    output             tx,                  // Outgoing serial line
    input              tx_valid,            // Assert to begin transmission
    input        [7:0] tx_byte,             // Byte to tx_valid
    output             rx_valid,            // Indicates that a byte has been rx_valid
    output       [7:0] rx_byte,             // Byte rx_valid
    output wire        rx_busy,             // Low when receive line is idle.
    output wire        tx_busy,             // Low when tx_valid line is idle.
    output wire        recv_error,          // Indicates error in receiving packet.
    output logic [3:0] rx_samples,
    output logic [3:0] rx_sample_countdown
);

    // http://www.sunburst-design.com/papers/CummingsHDLCON2002_Parameters_rev1_2.pdf

    localparam ONE_BAUD_CNT = CLK_FREQ / BAUD_RATE;

    //** SYMBOLIC STATE DECLARATIONS ******************************

    typedef enum {
        RX_IDLE,
        RX_CHECK_START,
        RX_SAMPLE_BITS,
        RX_READ_BITS,
        RX_CHECK_STOP,
        RX_DELAY_RESTART,
        RX_ERROR,
        RX_RECEIVED
    } rx_state_t;

    typedef enum {
        TX_IDLE,
        TX_SENDING,
        TX_DELAY_RESTART,
        TX_RECOVER
    } tx_state_t;

    //** SIGNAL DECLARATIONS **************************************

    reg [$clog2(ONE_BAUD_CNT * 16) - 1:0] rx_clk;
    reg [$clog2(ONE_BAUD_CNT)         :0] tx_clk;

    rx_state_t recv_state = RX_IDLE;
    reg [3:0] rx_bits_remaining;
    reg [7:0] rx_data;

    reg tx_out = 1'b1;
    tx_state_t tx_state = TX_IDLE;
    reg [3:0] tx_bits_remaining;
    reg [7:0] tx_data;


    //** ASSIGN STATEMENTS ****************************************

    assign rx_valid = recv_state == RX_RECEIVED;
    assign recv_error = recv_state == RX_ERROR;
    assign rx_busy = recv_state != RX_IDLE;
    assign rx_byte = rx_data;

    assign tx = tx_out;
    assign tx_busy = tx_state != TX_IDLE;

    //** Body *****************************************************

    always_ff @(posedge clk) begin
        if (!rstn) begin
            recv_state = RX_IDLE;
            tx_state = TX_IDLE;
            rx_data = '0;
        end

        // Countdown timers for the receiving and transmitting
        // state machines are decremented.

        if (rx_clk) begin
            rx_clk = rx_clk - 1'd1;
        end

        if (tx_clk) begin
            tx_clk = tx_clk - 1'd1;
        end


        //** Receive state machine ************************************

        case (recv_state)
            RX_IDLE: begin
                // A low pulse on the receive line indicates the
                // start of data.
                if (!rx) begin
                    // Wait 1/2 of the bit period
                    rx_clk = ONE_BAUD_CNT / 2;
                    recv_state = RX_CHECK_START;
                end
            end

            RX_CHECK_START: begin
                if (!rx_clk) begin
                    // Check the pulse is still there
                    if (!rx) begin
                        // Pulse still there - good
                        // Wait the bit period plus 3/8 of the next
                        rx_clk = (ONE_BAUD_CNT / 2) + (ONE_BAUD_CNT * 3) / 8;
                        rx_bits_remaining = 8;
                        recv_state = RX_SAMPLE_BITS;
                        rx_samples = 0;
                        rx_sample_countdown = 5;
                    end else begin
                        // Pulse lasted less than half the period -
                        // not a valid transmission.
                        recv_state = RX_ERROR;
                    end
                end
            end

            RX_SAMPLE_BITS: begin
                // sample the rx line multiple times 
                if (!rx_clk) begin
                    if (rx) begin
                        rx_samples = rx_samples + 1'd1;
                    end
                    rx_clk = ONE_BAUD_CNT / 8;
                    rx_sample_countdown = rx_sample_countdown - 1'd1;
                    recv_state = rx_sample_countdown ? RX_SAMPLE_BITS : RX_READ_BITS;
                end
            end

            RX_READ_BITS: begin
                if (!rx_clk) begin
                    // Should be finished sampling the pulse here.
                    // Update and prep for next
                    if (rx_samples > 3) begin
                        rx_data = {1'd1, rx_data[7:1]};
                    end else begin
                        rx_data = {1'd0, rx_data[7:1]};
                    end

                    rx_clk = (ONE_BAUD_CNT * 3) / 8;
                    rx_samples = 0;
                    rx_sample_countdown = 5;
                    rx_bits_remaining = rx_bits_remaining - 1'd1;

                    if (rx_bits_remaining) begin
                        recv_state = RX_SAMPLE_BITS;
                    end else begin
                        recv_state = RX_CHECK_STOP;
                        rx_clk = ONE_BAUD_CNT / 2;
                    end
                end
            end

            RX_CHECK_STOP: begin
                if (!rx_clk) begin
                    // Should resume half-way through the stop bit
                    // This should be high - if not, reject the
                    // transmission and signal an error.
                    recv_state = rx ? RX_RECEIVED : RX_ERROR;
                end
            end



            RX_ERROR: begin
                // There was an error receiving.
                // Raises the recv_error flag for one clock
                // cycle while in this state and then waits
                // 2 bit periods before accepting another
                // transmission.
                rx_clk = 8 * ONE_BAUD_CNT;
                recv_state = RX_DELAY_RESTART;
            end

            // why is this state needed?  Why not go to idle and wait for next? 

            RX_DELAY_RESTART: begin
                // Waits a set number of cycles before accepting
                // another transmission.
                recv_state = rx_clk ? RX_DELAY_RESTART : RX_IDLE;
            end


            RX_RECEIVED: begin
                // Successfully rx_valid a byte.
                // Raises the rx_valid flag for one clock
                // cycle while in this state.
                recv_state = RX_IDLE;
            end

        endcase


        //** Transmit state machine ***********************************

        case (tx_state)
            TX_IDLE: begin
                if (tx_valid) begin
                    // If the tx_valid flag is raised in the idle
                    // state, start transmitting the current content
                    // of the tx_byte input.
                    tx_data = tx_byte;
                    // Send the initial, low pulse of 1 bit period
                    // to signal the start, followed by the data
                    //  tx_clk_divider =  clock_divide;                                
                    tx_clk = ONE_BAUD_CNT;
                    tx_out = 0;
                    tx_bits_remaining = 8;
                    tx_state = TX_SENDING;
                end
            end

            TX_SENDING: begin
                if (!tx_clk) begin
                    if (tx_bits_remaining) begin
                        tx_bits_remaining = tx_bits_remaining - 1'd1;
                        tx_out = tx_data[0];
                        tx_data = {1'b0, tx_data[7:1]};
                        tx_clk = ONE_BAUD_CNT;
                        tx_state = TX_SENDING;
                    end else begin
                        // Set delay to send out 2 stop bits.
                        tx_out   = 1;
                        tx_clk   = ONE_BAUD_CNT;  // tx_countdown = 16;
                        tx_state = TX_DELAY_RESTART;
                    end
                end
            end

            TX_DELAY_RESTART: begin
                // Wait until tx_countdown reaches the end before
                // we send another transmission. This covers the
                // "stop bit" delay.
                tx_state = tx_clk ? TX_DELAY_RESTART : TX_RECOVER;  // TX_IDLE;
            end

            TX_RECOVER: begin
                // Wait unitil the tx_valid line is deactivated.  This prevents repeated characters
                tx_state = tx_valid ? TX_RECOVER : TX_IDLE;

            end

        endcase
    end

endmodule
