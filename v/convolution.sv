// `default_nettype none

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

    logic signed [2:0] KERNEL[3][3];

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
    assign input_value.valid = i_val_valid;
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

    always_ff @(posedge i_clk, negedge i_rst_n) begin
        if (!i_rst_n) begin
            for (int i = 0; i < 3; i++)
                for (int j = 0; j < 3; j++)
                    _internal_grid[i][j] <= '0;
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

    // Always compute both Gx and Gy from the same grid
    logic signed [17:0] gx, gy;
    always_comb begin
        gx = 0;
        gy = 0;
        for (int i = 0; i < 3; i++) begin
            for (int j = 0; j < 3; j++) begin
                gx += $signed(_internal_grid[i][j].value) * $signed(
                    (i == 0 && j == 0) ? 3'sd1 * -1 : (i == 0 && j == 2) ? 3'sd1 :
                    (i == 1 && j == 0) ? 3'sd2 * -1 : (i == 1 && j == 2) ? 3'sd2 :
                    (i == 2 && j == 0) ? 3'sd1 * -1 : (i == 2 && j == 2) ? 3'sd1 : 3'sd0);
                gy += $signed(_internal_grid[i][j].value) * $signed(
                    (i == 0 && j == 0) ? 3'sd1 * -1 : (i == 0 && j == 1) ? 3'sd2 * -1 : (i == 0 && j == 2) ? 3'sd1 * -1 :
                    (i == 2 && j == 0) ? 3'sd1      : (i == 2 && j == 1) ? 3'sd2      : (i == 2 && j == 2) ? 3'sd1      : 3'sd0);
            end
        end
    end

    logic [17:0] abs_gx, abs_gy;
    assign abs_gx = ($signed(gx) < 0) ? -gx : gx;
    assign abs_gy = ($signed(gy) < 0) ? -gy : gy;

    always_ff @(posedge i_clk) begin
        if (i_horizontal) begin
            // Vertical edge filter: output |Gx| unchanged
            o_val <= abs_gx;
        end else begin
            // Horizontal edge filter: saturating subtract |Gx| from |Gy|
            // Wherever a vertical edge also fired, it gets cancelled out
            o_val <= (abs_gy > abs_gx) ? (abs_gy - abs_gx) : 18'd0;
        end
        o_val_valid <= i_val_valid;
    end

endmodule