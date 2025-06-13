module uart_ddos
#(  
    parameter BAUD_RATE  = 9600,
    parameter CLK_FREQ   = 50_000_000,
    parameter W_DIGIT    = 4)  
(   
    input        clk,
    input        rstn,
    input        rx,
    input        key,
    output [7:0] abcdefgh,
    output [3:0] digit,
    output       tx,
    output       ready
);

    //////////// CONNECTIONS ////////////
    // UART //
    logic [7:0] rx_data, tx_data;
    logic       rx_busy, tx_busy, rx_error, tx_valid, rx_valid;
    wire tx_out;
    assign tx = tx_out;
    logic key_prev, key_pressed;
    logic [2:0] cnt, cnt_next;
    
    always_ff @(posedge clk) begin
        if(~rstn) 
            key_prev <= '0;
        else
            key_prev <= key;
    end
    
    always_ff @(posedge clk) begin
        if(~rstn) 
            key_pressed <= '0;
        
        if(key_pressed & sb_state == IDLE_S)
            key_pressed <= '0;
        else if(~key & key_prev) key_pressed <= '1;
    end

    typedef enum {
        IDLE_S,
        SEND_BYTE,
        INCREMENT,
        WAIT
    } send_back_state_t;
    send_back_state_t sb_state, sb_next_state;
    
    // SEVEN SEGMENT (FOR DEBUG) //
    logic [              7:0] abcdefgh_r;
    logic [              3:0] digit_r;
    logic [W_DIGIT * 4 - 1:0] number;
    
    //////////// STATE MACHINE ////////////
    always_comb begin
        sb_next_state = sb_state;
        cnt_next = cnt;
        case (sb_state)
            IDLE_S:
                if(key_pressed) sb_next_state = SEND_BYTE;
            SEND_BYTE:
                sb_next_state = INCREMENT;
            INCREMENT:
                sb_next_state = WAIT;
            WAIT:
                if (~tx_busy) sb_next_state = IDLE_S;
        endcase
    end

    always_ff @(posedge clk) begin
        case (sb_state)
        SEND_BYTE: begin
            tx_data  <= 8'h63;
            tx_valid <= '1;
        end
        INCREMENT: begin
            tx_valid <= '0;
        end
        endcase
    end

    
    always_ff @( posedge clk ) begin
        if (!rstn) begin
            sb_state <= IDLE_S;
        end
        else begin
            sb_state <= sb_next_state;
        end
    end

    //////////// SEVEN-SEGMENT DISPLAY ////////////
    assign number      =   rx_data;
    assign abcdefgh    = ~ abcdefgh_r;
    assign digit       = ~ digit_r;

    uart #(
        .BAUD_RATE   (BAUD_RATE),   
        .CLK_FREQ(CLK_FREQ)   
    )
    uart_inst (
        .clk(clk),                       
        .rstn(rstn),               
        .rx(rx),                       
        .tx(tx_out),                        
        .tx_valid(tx_valid),          
        .tx_byte(tx_data),              
        .rx_valid(rx_valid),        
        .rx_byte(rx_data),              
        .rx_busy(rx_busy),         
        .tx_busy(tx_busy),    
    );
    
    seven_segment_display #(
        .w_digit(W_DIGIT)
    )
    seven_segment_display_inst
    (
        .clk(clk),
        .rstn(rstn),
        .number(number),
        .abcdefgh(abcdefgh_r),
        .digit(digit_r)
    );

endmodule