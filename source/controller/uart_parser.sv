// START_BIT: 0x55
// STOP_BIT: 0x00
// Module accepts DATA_WIDTH-width data packet
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
                    8'h04,
                    8'h00:   next_state = STATE_FINISH;
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

endmodule
