//`default_nettype none

module convolution #(
    parameter int N = 3,
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

    localparam int KERNEL[N][N] = '{
        '{-1, 0, 1},
        '{-2, 0, 2},
        '{-1, 0, 1}
    };

    typedef struct packed {
        logic valid;
        logic [DATA_WIDTH-1:0] value;
    } value_t;

    value_t _internal_grid[N][N];

    /* Shift each row down one */
    always_ff @(posedge i_clk, negedge i_rst_n) begin
        for (int i = 0; i < N; i++) begin
            for (int j = 1; j < N; j++) begin
                if (!i_rst_n) begin
                    _internal_grid[i][j] <= '0;
                end
                else begin
                    _internal_grid[i][j] <= _internal_grid[i][j-1];
                end
            end
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
                .shiftout(_internal_grid[i][0])
            );
        end
    endgenerate

    logic [DATA_WIDTH-1+3:0] val;
    always_comb begin
        /* Perform convolution */
        val = 0;
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                val += _internal_grid[i][j].value * KERNEL[i][j];
            end
        end
    end
    
    always_ff @(posedge i_clk) begin
        /* Take absolute value */
        o_val <= (val < 0) ? -val : val;
        o_val_valid <= _internal_grid[N-1][N-1].valid;
    end

endmodule

