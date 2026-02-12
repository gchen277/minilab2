//`default_nettype none

module convolution #(
    parameter int DATA_WIDTH = 12
)(
    input  logic i_clk,
    input  logic i_rst_n,

    /* Convolution stuff */
    input  logic i_val_valid,
    input  logic [DATA_WIDTH-1:0] i_val,
    output logic o_val_valid,
    output logic [DATA_WIDTH-1+3:0] o_val
);

    localparam int KERNEL[3][3] = '{
        '{-4, 0, 4},
        '{-8, 0, 8},
        '{-4, 0, 4}
    };

    typedef struct packed {
        logic valid;
        logic [DATA_WIDTH-1:0] value;
    } value_t;

    value_t _internal_fifo_out[2];
    value_t _internal_grid[3][3];

    value_t input_value;
    assign input_value.valid = 1'b1;
    assign input_value.value = i_val;

    Line_Buffer2 line_inst (
        .clken(i_val_valid),
        .clock(i_clk),
        .shiftin(_internal_grid[0][2]),
        .shiftout(_internal_fifo_out[0])
    );

    Line_Buffer2 line_inst2 (
        .clken(i_val_valid),
        .clock(i_clk),
        .shiftin(_internal_grid[1][2]),
        .shiftout(_internal_fifo_out[1])
    );

    /* Shift each row down one */
    always_ff @(posedge i_clk, negedge i_rst_n) begin
        if (!i_rst_n) begin
            for (int i = 0; i < 3; i++) begin
                for (int j = 0; j < 3; j++) begin
                    _internal_grid[i][j] <= '0;
                end
            end
        end else if (i_val_valid) begin
            _internal_grid[0][0] <= input_value;
            _internal_grid[0][1] <= _internal_grid[0][0];
            _internal_grid[0][2] <= _internal_grid[0][1];
            _internal_grid[1][0] <= _internal_fifo_out[0];
            _internal_grid[1][1] <= _internal_grid[1][0];
            _internal_grid[1][2] <= _internal_grid[1][1];
            _internal_grid[2][0] <= _internal_fifo_out[1];
            _internal_grid[2][1] <= _internal_grid[2][0];
            _internal_grid[2][2] <= _internal_grid[2][1];
        end
    end

    logic [DATA_WIDTH-1+3:0] val;
    always_comb begin
        /* Perform convolution */
        val = 
            KERNEL[0][0] * $signed(_internal_grid[0][0].value) +
            KERNEL[0][1] * $signed(_internal_grid[0][1].value) +
            KERNEL[0][2] * $signed(_internal_grid[0][2].value) +
            KERNEL[1][0] * $signed(_internal_grid[1][0].value) +
            KERNEL[1][1] * $signed(_internal_grid[1][1].value) +
            KERNEL[1][2] * $signed(_internal_grid[1][2].value) +
            KERNEL[2][0] * $signed(_internal_grid[2][0].value) +
            KERNEL[2][1] * $signed(_internal_grid[2][1].value) +
            KERNEL[2][2] * $signed(_internal_grid[2][2].value);
    end
    
    always_ff @(posedge i_clk) begin
        /* Take absolute value */
        o_val <= ($signed(val) < 0) ? -$signed(val) : val;
        o_val_valid <= /*_internal_grid[N-1][N-1].valid &&*/ i_val_valid;
    end

endmodule

