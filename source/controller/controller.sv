`include "uart_parser.svh"
module controller
#(  parameter DATA_WIDTH = 32, // Разрядность шины входных данных
    parameter MAX_LEN    = 256,// Максимальный размер пакета 
    parameter ARRAY_W    = 10, // Количество строк в систолическом массиве
    parameter ARRAY_L    = 10, // Количество столбцов в систолическом массиве
    parameter ARRAY_A_W  = 4,  // Количество строк в массиве данных
    parameter ARRAY_A_L  = 3,  // Количество столбцов в массиве данных
    parameter ARRAY_W_W  = 3,  // Количество строк в массиве весов
    parameter ARRAY_W_L  = 4,  // Количество столбцов в массиве весов
    parameter BAUD_RATE  = 9600,
    parameter CLK_FREQ   = 50_000_000,
    parameter W_DIGIT    = 4)  
(   
    input        clk,
    input        rstn,
    input        rx,
    output [7:0] abcdefgh,
    output [3:0] digit,
    output       tx,
    output       ready
);

    //////////// CONNECTIONS ////////////
    // UART //
    logic [7:0] rx_data, tx_data;
    logic       rx_busy, tx_busy, rx_error, tx_valid, rx_valid;

    // PARSER //
    logic [             7:0] parser_data_len;
    logic [             7:0] parser_cmd;
    logic [DATA_WIDTH - 1:0] parser_data;
    logic                    parser_valid;

    // PARSER STATE MACHINE //
    typedef enum { 
        IDLE, 
        FETCH_WEIGHTS, 
        LOAD_WEIGHTS, 
        FETCH_DATA, 
        START_COMP, 
        WAIT_RES,
        SEND_BACK 
    } state_t;
    state_t state, next_state;

    logic [$clog2(ARRAY_A_W > ARRAY_W_W ? ARRAY_A_W : ARRAY_W_W) - 1:0] row_ptr;
    logic [$clog2(ARRAY_A_L > ARRAY_W_L ? ARRAY_A_L : ARRAY_W_L) - 1:0] col_ptr;
    logic [                               $clog2(2 * DATA_WIDTH) - 1:0] bit_ptr;

    typedef enum {
        IDLE_SB,
        SEND_BYTE_SB,
        INCREMENT_SB,
        WAIT_SB
    } send_back_state_t;
    send_back_state_t sb_state, sb_next_state;
    
    // SEVEN SEGMENT (FOR DEBUG) //
    logic [              7:0] abcdefgh_r;
    logic [              3:0] digit_r;
    logic [W_DIGIT * 4 - 1:0] number;
    
    // SYSARRAY FETCHER //
    logic signed [    DATA_WIDTH  - 1:0] sa_input_data   [0:ARRAY_A_W - 1][0:ARRAY_A_L - 1];
    logic signed [    DATA_WIDTH  - 1:0] sa_weights      [0:ARRAY_W_W - 1][0:ARRAY_W_L - 1];
    logic signed [2 * DATA_WIDTH  - 1:0] sa_out_data     [0:ARRAY_A_W - 1][0:ARRAY_W_L - 1];
    logic                                sa_ready                                          ;
    logic                                sa_weights_load                                   ;
    logic                                sa_start_comp                                     ;

    //////////// STATE MACHINE ////////////
    always_comb begin
        next_state = state;
        case (state)
            IDLE:
                if (parser_valid & (parser_cmd == `CMD_FETCH_WEIGHTS)) next_state = FETCH_WEIGHTS;
            FETCH_WEIGHTS:
                if (parser_valid & (parser_cmd == `CMD_LOAD_WEIGHTS)) next_state = LOAD_WEIGHTS;
            LOAD_WEIGHTS:
                                                                    next_state = FETCH_DATA;
            FETCH_DATA:
                if (parser_valid & (parser_cmd == `CMD_START_COMP)) next_state = START_COMP;
            START_COMP:
                                                          next_state = WAIT_RES;
            WAIT_RES:
                if (                            sa_ready) next_state = SEND_BACK;
            SEND_BACK:
                if ((row_ptr == ARRAY_A_W - 1) & (col_ptr == ARRAY_W_L - 1))
                                                          next_state = IDLE;
        endcase
    end
    
    always_comb begin
        sb_next_state = sb_state;
        case (sb_state)
            IDLE_SB:
                if(state == SEND_BACK) sb_next_state = SEND_BYTE_SB;
            SEND_BYTE_SB:
                sb_next_state = INCREMENT_SB;
            INCREMENT_SB:
                sb_next_state = WAIT_SB;
            WAIT_SB:
                if (~tx_busy) sb_next_state = SEND_BYTE_SB;
        endcase
    end


    assign sa_weights_load = state == LOAD_WEIGHTS;
    assign sa_start_comp   = state == START_COMP;
    assign ready           = (state == SEND_BACK) & (next_state == IDLE);

    always_ff @(posedge clk) begin
        case (state)
            IDLE: begin
                tx_valid <= '0;
                if (parser_valid & (parser_cmd == 8'h02)) begin
                    row_ptr <= '0;
                    col_ptr <= '0;
                end
            end
            FETCH_WEIGHTS:
                if (parser_valid & (parser_cmd == 8'h01)) begin
                    sa_weights[row_ptr][col_ptr] <= parser_data;

                    if (col_ptr == ARRAY_W_L - 1) begin
                        row_ptr <= row_ptr + 'd1;
                        col_ptr <= '0;
                    end
                    else col_ptr <= col_ptr + 'd1;
                end
            LOAD_WEIGHTS: begin
                row_ptr <= '0;
                col_ptr <= '0;
            end
            FETCH_DATA:
                if (parser_valid & (parser_cmd == 8'h01)) begin
                    sa_input_data[row_ptr][col_ptr] <= parser_data;

                    if (col_ptr == ARRAY_A_L - 1) begin
                        row_ptr <= row_ptr + 'd1;
                        col_ptr <= '0;
                    end
                    else col_ptr <= col_ptr + 'd1;
                end
            START_COMP: begin
                row_ptr  <= '0;
                col_ptr  <= '0;
                bit_ptr  <= '0;
            end
            SEND_BACK: begin
                case (sb_state)
                SEND_BYTE_SB: begin
                    tx_data  <= 8'h55;
                    tx_valid <= '1;
                end
                INCREMENT_SB: begin
                    tx_valid <= '0;
                    if (bit_ptr == DATA_WIDTH - 8)
                        bit_ptr <= '0;
                    else
                        bit_ptr <= bit_ptr + 'd8;

                    if (col_ptr == ARRAY_W_L - 1) begin
                        row_ptr <= row_ptr + 'd1;
                        col_ptr <= '0;
                    end
                    else col_ptr <= col_ptr + 'd1;
                end
                endcase
            end

        endcase
    end

    always_ff @( posedge clk ) begin
        if (!rstn) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end
    
    always_ff @( posedge clk ) begin
        if (!rstn) begin
            sb_state <= IDLE_SB;
        end
        else begin
            sb_state <= sb_next_state;
        end
    end

    //////////// SEVEN-SEGMENT DISPLAY ////////////
    assign number      =   state;
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
        .tx(tx),                        
        .tx_valid(tx_valid),          
        .tx_byte(tx_data),              
        .rx_valid(rx_valid),        
        .rx_byte(rx_data),              
        .rx_busy(rx_busy),         
        .tx_busy(tx_busy)
    );
    
    uart_parser #(
        .DATA_WIDTH(DATA_WIDTH)
    )
    uart_parser_inst (
        .clk(clk),
        .rstn(rstn),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .cmd(parser_cmd),
        .data(parser_data),
        .valid(parser_valid)
    );

    sys_array_fetcher #(.DATA_WIDTH(DATA_WIDTH),
                        .ARRAY_W(ARRAY_W), .ARRAY_L(ARRAY_L),
                        .ARRAY_W_W(ARRAY_W_W), .ARRAY_W_L(ARRAY_W_L),
                        .ARRAY_A_W(ARRAY_A_W), .ARRAY_A_L(ARRAY_A_L)) 
    sys_array_fetcher_inst
    (
        .clk(clk),
        .reset_n(rstn),
        .weights_load(sa_weights_load),
        .start_comp(sa_start_comp),
        .input_data(sa_input_data),
        .weights(sa_weights),
        .ready(sa_ready),
        .out_data(sa_out_data)
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