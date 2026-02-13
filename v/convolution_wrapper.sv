//`default_nettype none

module convolution_wrapper(
    input  logic i_clk,
    input  logic i_rst_n,

    input  logic i_greyscale,
    input  logic i_horizontal,

    input  logic [11:0] i_red,
    input  logic [11:0] i_green,
    input  logic [11:0] i_blue,
    input  logic i_valid,

    input  logic [5:0] i_shift_amt,

    output logic [11:0] o_red,
    output logic [11:0] o_green,
    output logic [11:0] o_blue,
    output logic o_valid
);

    logic [11:0] value;
    assign value = (i_blue * 2 + i_green * 3 + i_red * 3)/8;

    logic [17:0] convolution_value;
    logic convolution_valid;
    convolution convolution_inst (
        .i_clk,
        .i_rst_n,

        .i_horizontal(i_horizontal),

        .i_val_valid(i_valid),
        .i_val(value),

        .o_val_valid(convolution_valid),
        .o_val(convolution_value)
    );

    logic [11:0] o_val;
    assign o_val = (i_greyscale) ? value : convolution_value[i_shift_amt+:11];
    assign o_valid = (i_greyscale) ? i_valid : convolution_valid;
    assign o_red = o_val;
    assign o_green = o_val;
    assign o_blue = o_val;

endmodule
