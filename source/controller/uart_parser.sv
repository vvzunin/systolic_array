// START_BIT: 0x55
// Module accepts MAX_LEN-byte-width numbers one-by-one
module uart_parser 
#(
    parameter DATA_WIDTH = 32
)
(
    input wire       clk     ,
    input wire       rstn    , 
    input wire [7:0] rx_data ,
    input wire       rx_valid,

    output logic [             7:0] cmd ,
    output logic [DATA_WIDTH - 1:0] data,
    output logic                    valid
);

    // Состояния конечного автомата
    typedef enum {
        STATE_IDLE,
        STATE_CMD,
        STATE_DATA,
        STATE_FINISH
    } state_t;

    state_t state, next_state;
    reg [$clog2(DATA_WIDTH):0] data_ptr;

    always_comb begin
        next_state = state;

        case (state)
        STATE_IDLE: begin
            if (rx_valid && rx_data == 8'h55)
                next_state = STATE_CMD;
        end
        STATE_CMD: begin
            if (rx_valid)
                case (rx_data)
                    8'h01:   next_state = STATE_DATA;
                    8'h02,
                    8'h03,
                    8'h04:   next_state = STATE_FINISH;
                    default: next_state = STATE_IDLE;
                endcase
        end
        STATE_DATA: begin
            if (rx_valid && data_ptr == DATA_WIDTH)
                next_state = STATE_FINISH;
        end
        STATE_FINISH: begin
            next_state = STATE_IDLE;
        end
        endcase
    end

    always_ff @(negedge clk) begin
        case (state)
            STATE_CMD:
                if (rx_valid) begin
                    cmd <= rx_data;
                    data_ptr <= '0;
                end
            STATE_DATA:
                if (rx_valid) begin
                    data[data_ptr +: 'd8] <= rx_data;
                    data_ptr              <= data_ptr + 'd8;
                end
        endcase
    end

    assign valid = state == STATE_FINISH;

    always_ff @(posedge clk) begin
        if ( ~ rstn) begin
            state <= STATE_IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    // always @(posedge clk) begin
    //     if (!rstn) begin
    //         current_state <= STATE_IDLE;
    //         valid <= 0;
    //         data_ptr <= 0;
    //     end 
    //     else begin
    //         case (current_state)
    //             STATE_IDLE: begin
    //                 if (rx_valid && rx_data == 8'h55) begin
    //                     current_state <= STATE_CMD;
    //                 end
    //             end

    //             STATE_CMD: begin
    //                 if (rx_valid) begin
    //                     cmd <= rx_data;
    //                     case (rx_data)
    //                         8'h01:   current_state <= STATE_FINISH;
    //                         8'h02,
    //                         8'h03:   current_state <= STATE_LEN;
    //                         default: current_state <= STATE_IDLE;
    //                     endcase
    //                 end
    //             end

    //             STATE_LEN: begin
    //                 if (rx_valid) begin
    //                     data_len <= rx_data;
    //                     current_state <= STATE_DATA;
    //                     data_ptr <= 0;
    //                 end
    //             end

    //             STATE_DATA: begin
    //                 if (rx_valid) begin
    //                     data[data_ptr] <= rx_data;
    //                     data_ptr       <= data_ptr + 1;
    //                     if (data_ptr == data_len - 1) begin
    //                         current_state <= STATE_FINISH;
    //                     end
    //                 end
    //             end

    //             STATE_FINISH: begin
    //                 valid <= 1;
    //                 current_state <= STATE_IDLE;
    //             end

    //             default: begin
    //                 current_state <= STATE_IDLE;
    //             end
    //         endcase
    //     end
    // end

endmodule
