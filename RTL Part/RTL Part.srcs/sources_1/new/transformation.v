`timescale 1ns / 1ps

module spectral_transform #(
    parameter FRAME_SIZE = 1024
)(
    input wire        clk,
    input wire        reset,

    input wire [31:0] spectrum_in,
    input wire        spectrum_valid,

    // Q16.16 pitch/shift ratio
    input wire [31:0] shift_ratio,
    input wire        analysis_done,

    output reg        transform_done,

    output reg [31:0] spectrum_out,
    output reg        spectrum_out_valid
);

    // =========================================================
    // INPUT SPECTRUM STORAGE
    // =========================================================

    reg [15:0] magnitude_mem [0:FRAME_SIZE-1];
    reg signed [15:0] phase_mem [0:FRAME_SIZE-1];


    // =========================================================
    // TRANSFORMED SPECTRUM STORAGE
    // =========================================================

    reg [15:0] transformed_magnitude [0:FRAME_SIZE-1];
    reg signed [15:0] transformed_phase [0:FRAME_SIZE-1];


    // =========================================================
    // COUNTERS
    // =========================================================

    reg [9:0] input_counter;
    reg [9:0] target_bin;
    reg [9:0] output_counter;


    // =========================================================
    // SOURCE BIN CALCULATION
    //
    // shift_ratio is Q16.16
    //
    // source_bin =
    //
    //     target_bin
    //     ----------
    //     shift_ratio
    //
    // In fixed point:
    //
    // source_bin =
    //     (target_bin << 16) / shift_ratio
    // =========================================================

    reg [63:0] source_calc;

    reg [9:0] source_bin;


    // =========================================================
    // FSM STATES
    // =========================================================

    localparam STATE_IDLE      = 3'd0;
    localparam STATE_CAPTURE   = 3'd1;
    localparam STATE_TRANSFORM = 3'd2;
    localparam STATE_OUTPUT    = 3'd3;
    localparam STATE_DONE      = 3'd4;

    reg [2:0] state;


    // =========================================================
    // MAIN FSM
    // =========================================================

    always @(posedge clk) begin

        if (reset) begin

            input_counter      <= 10'd0;
            target_bin         <= 10'd0;
            output_counter     <= 10'd0;

            source_calc        <= 64'd0;
            source_bin         <= 10'd0;

            spectrum_out       <= 32'd0;
            spectrum_out_valid <= 1'b0;
            transform_done     <= 1'b0;

            state              <= STATE_IDLE;

        end

        else begin

            spectrum_out_valid <= 1'b0;
            transform_done     <= 1'b0;

            case (state)


                // =================================================
                // IDLE
                // =================================================

                STATE_IDLE: begin

                    if (analysis_done) begin

                        input_counter <= 10'd0;

                        state <= STATE_CAPTURE;

                    end

                end


                // =================================================
                // CAPTURE INPUT SPECTRUM
                // =================================================

                STATE_CAPTURE: begin

                    if (spectrum_valid) begin

                        magnitude_mem[input_counter]
                            <= spectrum_in[15:0];

                        phase_mem[input_counter]
                            <= spectrum_in[31:16];

                        if (input_counter == FRAME_SIZE-1) begin

                            target_bin <= 10'd0;

                            state <= STATE_TRANSFORM;

                        end

                        else begin

                            input_counter <=
                                input_counter + 1'b1;

                        end

                    end

                end


                // =================================================
                // TRANSFORM
                // =================================================

                STATE_TRANSFORM: begin


                    // -------------------------------------------------
                    // DC BIN
                    // -------------------------------------------------

                    if (target_bin == 10'd0) begin

                        transformed_magnitude[target_bin]
                            <= magnitude_mem[0];

                        transformed_phase[target_bin]
                            <= phase_mem[0];

                    end


                    // -------------------------------------------------
                    // POSITIVE FREQUENCY BINS
                    // -------------------------------------------------

                    else if (target_bin < FRAME_SIZE/2) begin

                        if (shift_ratio != 0) begin

                            // Q16.16 division
                            //
                            // source_bin =
                            // (target_bin << 16) / shift_ratio

                            source_calc =
                                ({54'd0, target_bin} << 16)
                                / shift_ratio;

                            source_bin =
                                source_calc[9:0];

                        end

                        else begin

                            // Safety fallback: no shift

                            source_bin =
                                target_bin;

                        end


                        // ------------------------------------------------
                        // VALID SOURCE BIN
                        // ------------------------------------------------

                        if (source_bin < FRAME_SIZE/2) begin

                            transformed_magnitude[target_bin]
                                <= magnitude_mem[source_bin];

                            transformed_phase[target_bin]
                                <= phase_mem[source_bin];

                        end

                        else begin

                            transformed_magnitude[target_bin]
                                <= 16'd0;

                            transformed_phase[target_bin]
                                <= 16'sd0;

                        end

                    end


                    // -------------------------------------------------
                    // NYQUIST BIN
                    // -------------------------------------------------

                    else if (target_bin == FRAME_SIZE/2) begin

                        transformed_magnitude[target_bin]
                            <= magnitude_mem[FRAME_SIZE/2];

                        transformed_phase[target_bin]
                            <= phase_mem[FRAME_SIZE/2];

                    end


                    // -------------------------------------------------
                    // NEGATIVE FREQUENCY BINS
                    // -------------------------------------------------

                    else begin

                        transformed_magnitude[target_bin]
                            <= transformed_magnitude[
                                FRAME_SIZE - target_bin
                            ];

                        transformed_phase[target_bin]
                            <= -transformed_phase[
                                FRAME_SIZE - target_bin
                            ];

                    end


                    // -------------------------------------------------
                    // FINISH TRANSFORM
                    // -------------------------------------------------

                    if (target_bin == FRAME_SIZE-1) begin

                        output_counter <= 10'd0;

                        state <= STATE_OUTPUT;

                    end

                    else begin

                        target_bin <=
                            target_bin + 1'b1;

                    end

                end


                // =================================================
                // OUTPUT
                // =================================================

                STATE_OUTPUT: begin

                    spectrum_out_valid <= 1'b1;

                    spectrum_out <= {

                        transformed_phase[output_counter],

                        transformed_magnitude[output_counter]

                    };

                    if (output_counter == FRAME_SIZE-1) begin

                        state <= STATE_DONE;

                    end

                    else begin

                        output_counter <=
                            output_counter + 1'b1;

                    end

                end


                // =================================================
                // DONE
                // =================================================

                STATE_DONE: begin

                    transform_done <= 1'b1;

                    state <= STATE_IDLE;

                end


                // =================================================
                // DEFAULT
                // =================================================

                default: begin

                    state <= STATE_IDLE;

                end

            endcase

        end

    end

endmodule