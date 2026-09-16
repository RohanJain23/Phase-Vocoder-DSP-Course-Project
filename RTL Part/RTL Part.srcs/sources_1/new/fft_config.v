module fft_config (
    input  wire        clk,
    input  wire        reset,

    output wire [15:0] s_axis_config_tdata,
    output reg         s_axis_config_tvalid,
    input  wire        s_axis_config_tready
);

    // =========================================================
    // FFT CONFIGURATION
    //
    // [15:11] = padding
    // [10:1]  = SCALE_SCH
    // [0]     = FWD_INV
    //
    // FWD_INV = 1 -> Forward FFT
    //
    // SCALE_SCH = 1010101010
    // =========================================================

    assign s_axis_config_tdata = 16'h0555;

    // =========================================================
    // CONFIGURATION HANDSHAKE
    // =========================================================

    always @(posedge clk) begin

        if (reset) begin
            s_axis_config_tvalid <= 1'b1;
        end

        else if (s_axis_config_tvalid &&
                 s_axis_config_tready) begin

            s_axis_config_tvalid <= 1'b0;
        end

    end

endmodule