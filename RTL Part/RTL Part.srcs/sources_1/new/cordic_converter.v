module spectrum_to_cordic (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] spectrum_in,
    input  wire        spectrum_valid,

    output wire [31:0] cartesian_tdata,
    output wire        cartesian_tvalid,

    output wire [15:0] phase_tdata,
    output wire        phase_tvalid
);

    assign cartesian_tdata = {
        16'd0,
        spectrum_in[15:0]
    };

    assign phase_tdata = spectrum_in[31:16];

    assign cartesian_tvalid = spectrum_valid;
    assign phase_tvalid     = spectrum_valid;

endmodule