`default_nettype none

module convolution_wrapper(
    input  logic i_clk,
    input  logic i_rst_n,

    input  logic [11:0] i_red,
    input  logic [11:0] i_green,
    input  logic [11:0] i_blue,
    input  logic i_valid,

    output logic [11:0] o_red,
    output logic [11:0] o_green,
    output logic [11:0] o_blue,
    output logic o_valid
);

    logic [11:0] value;
    assign value = (i_blue * 2 + i_green * 3 + i_red * 3}/8;

    logic [14:0] convolution_value;
    convolution convolution_inst (
        .i_clk,
        .i_rst_n,

        .i_val_valid(i_valid),
        .i_val(value)

        .o_val_valid(o_valid)
        .o_val(convolution_value)
    );

    assign o_red = convolution_value[14:3];
    assign o_green = convolution_value[14:3];
    assign o_blue = convolution_value[14:3];

endmodule

