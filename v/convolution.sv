//`default_nettype none

module convolution #(
    parameter int DATA_WIDTH = 12
)(
    input  logic i_clk,
    input  logic i_rst_n,
    input  logic i_horizontal,

    /* Convolution stuff */
    input  logic i_val_valid,
    input  logic [DATA_WIDTH-1:0] i_val,
    output logic o_val_valid,
    output logic [17:0] o_val
);

    logic signed [2:0] KERNEL[N][N];

    always_comb begin
        if (i_horizontal) begin
            KERNEL = '{
                '{-1, 0, 1},
                '{-2, 0, 2},
                '{-1, 0, 1}
            };
        end
        else begin
            KERNEL = '{
                '{ -1, -2, -1},
                '{  0,  0,  0},
                '{  1,  2,  1}
            };
        end
    end

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
        for (int i = 0; i < 3; i++) begin
            if (!i_rst_n) begin
                _internal_grid[i][0] <= '0;
            end
            else begin
                _internal_grid[i][0] <= _internal_fifo_out[i];
            end
            for (int j = 1; j < 3; j++) begin
                if (!i_rst_n) begin
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

    value_t input_value;
    assign input_value.valid = i_val_valid;
    assign input_value.value = i_val;
    
    genvar i;
    generate
        for (i = 0; i < N; i++) begin : gen_line_buffer
            Line_Buffer2 line_inst (
                .clken(i_val_valid),
                .clock(i_clk),
                .shiftin((i == 0) ? input_value : _internal_grid[i-1][N-1]),
                .taps1x(_internal_fifo_out[i])
            );
        end
    endgenerate

    logic signed [17:0] val;
    always_comb begin
        /* Perform convolution */
        val = 0;
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                val += $signed(_internal_grid[i][j].value) * KERNEL[i][j];
            end
        end
    end
    
    always_ff @(posedge i_clk) begin
        /* Take absolute value */
        o_val <= ($signed(val) < 0) ? -$signed(val) : val;
        o_val_valid <= /*_internal_grid[N-1][N-1].valid &&*/ i_val_valid;
    end

endmodule

