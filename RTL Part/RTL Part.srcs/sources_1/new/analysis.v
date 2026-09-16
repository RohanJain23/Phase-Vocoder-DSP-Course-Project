module spectral_analysis #(
    parameter FRAME_SIZE  = 1024,
    parameter SAMPLE_RATE = 44100
)(
    input wire        clk,
    input wire        reset,

    // =========================================================
    // CORDIC INPUT
    //
    // [31:16] = phase
    // [15:0]  = magnitude
    // =========================================================

    input wire [31:0] s_axis_tdata,
    input wire        s_axis_tvalid,

    // =========================================================
    // Transform handshake
    // =========================================================

    input wire        transform_done,

    // =========================================================
    // Analysis outputs
    // =========================================================

    output reg [9:0]  peak_bin,
    output reg [31:0] detected_freq,

    // Q16.16
    // 65536 = 1.0
    output reg [31:0] shift_ratio,

    output reg        analysis_done,

    // =========================================================
    // Spectrum stream to transform
    //
    // [31:16] = phase
    // [15:0]  = magnitude
    // =========================================================

    output reg [31:0] spectrum_out,
    output reg        spectrum_valid
);


    // =========================================================
    // CORDIC DATA
    // =========================================================

    wire [15:0] magnitude;
    wire signed [15:0] phase;

    assign magnitude = s_axis_tdata[15:0];
    assign phase     = s_axis_tdata[31:16];


    // =========================================================
    // SPECTRUM MEMORY
    // =========================================================

    reg [15:0] magnitude_mem [0:FRAME_SIZE-1];
    reg signed [15:0] phase_mem [0:FRAME_SIZE-1];


    // =========================================================
    // TUNING ROM
    // =========================================================

    reg [15:0] tuning_rom [0:87];

    initial begin
        $readmemh("tuning_rom.mem", tuning_rom);
    end


    // =========================================================
    // COUNTERS
    // =========================================================

    reg [9:0] bin_counter;
    reg [9:0] stream_counter;


    // =========================================================
    // PEAK DETECTOR
    // =========================================================

    reg [15:0] max_magnitude;
    reg [9:0]  current_peak_bin;


    // =========================================================
    // ROM SEARCH
    // =========================================================

    reg [6:0] rom_counter;

    reg [15:0] closest_frequency;

    reg [31:0] smallest_difference;

    reg [31:0] difference;

    reg [31:0] detected_frequency_temp;


    // =========================================================
    // STATE MACHINE
    // =========================================================

    localparam STATE_RECEIVE   = 3'd0;
    localparam STATE_FREQ      = 3'd1;
    localparam STATE_ROM       = 3'd2;
    localparam STATE_RATIO     = 3'd3;
    localparam STATE_DONE_PULSE = 3'd4;
    localparam STATE_STREAM    = 3'd5;
    localparam STATE_WAIT      = 3'd6;

    reg [2:0] state;


    // =========================================================
    // MAIN
    // =========================================================

    always @(posedge clk) begin

        if (reset) begin

            bin_counter <= 10'd0;
            stream_counter <= 10'd0;

            max_magnitude <= 16'd0;
            current_peak_bin <= 10'd0;

            peak_bin <= 10'd0;
            detected_freq <= 32'd0;

            shift_ratio <= 32'd65536;

            analysis_done <= 1'b0;

            spectrum_out <= 32'd0;
            spectrum_valid <= 1'b0;

            rom_counter <= 7'd0;

            closest_frequency <= 16'd0;
            smallest_difference <= 32'hFFFFFFFF;

            difference <= 32'd0;
            detected_frequency_temp <= 32'd0;

            state <= STATE_RECEIVE;

        end

        else begin

            // Default outputs every cycle
            analysis_done  <= 1'b0;
            spectrum_valid <= 1'b0;


            case (state)


                // =================================================
                // RECEIVE FFT/CORDIC FRAME
                // =================================================

                STATE_RECEIVE: begin

                    if (s_axis_tvalid) begin

                        magnitude_mem[bin_counter]
                            <= magnitude;

                        phase_mem[bin_counter]
                            <= phase;


                        // -----------------------------------------
                        // Peak detector
                        //
                        // Ignore DC and negative-frequency bins.
                        // -----------------------------------------

                        if ((bin_counter != 10'd0) &&
                            (bin_counter < FRAME_SIZE/2) &&
                            (magnitude > max_magnitude)) begin

                            max_magnitude <= magnitude;

                            current_peak_bin <= bin_counter;

                        end


                        if (bin_counter == FRAME_SIZE-1) begin

                            state <= STATE_FREQ;

                        end

                        else begin

                            bin_counter <= bin_counter + 1'b1;

                        end

                    end

                end


                // =================================================
                // FREQUENCY
                // =================================================

                STATE_FREQ: begin

                    peak_bin <= current_peak_bin;


                    detected_frequency_temp =
                        (current_peak_bin * SAMPLE_RATE)
                        / FRAME_SIZE;


                    detected_freq <=
                        detected_frequency_temp;


                    rom_counter <= 7'd0;

                    smallest_difference <=
                        32'hFFFFFFFF;

                    closest_frequency <= 16'd0;


                    state <= STATE_ROM;

                end


                // =================================================
                // SEARCH NOTE ROM
                // =================================================

                STATE_ROM: begin

                    if (detected_frequency_temp >
                        tuning_rom[rom_counter]) begin

                        difference =
                            detected_frequency_temp -
                            tuning_rom[rom_counter];

                    end

                    else begin

                        difference =
                            tuning_rom[rom_counter] -
                            detected_frequency_temp;

                    end


                    if (difference < smallest_difference) begin

                        smallest_difference <= difference;

                        closest_frequency <=
                            tuning_rom[rom_counter];

                    end


                    if (rom_counter == 7'd87) begin

                        state <= STATE_RATIO;

                    end

                    else begin

                        rom_counter <= rom_counter + 1'b1;

                    end

                end


                // =================================================
                // CALCULATE PITCH RATIO
                // =================================================

                STATE_RATIO: begin

                    if (detected_frequency_temp != 0) begin

                        shift_ratio <=
                            (closest_frequency << 16)
                            / detected_frequency_temp;

                    end

                    else begin

                        shift_ratio <= 32'd65536;

                    end


                    // ---------------------------------------------
                    // IMPORTANT:
                    //
                    // Do NOT start streaming in this state.
                    //
                    // Give transform one clean cycle to see
                    // analysis_done.
                    // ---------------------------------------------

                    state <= STATE_DONE_PULSE;

                end


                // =================================================
                // ONE-CYCLE ANALYSIS-DONE PULSE
                // =================================================

                STATE_DONE_PULSE: begin

                    analysis_done <= 1'b1;

                    stream_counter <= 10'd0;

                    state <= STATE_STREAM;

                end


                // =================================================
                // STREAM STORED SPECTRUM
                // =================================================

                STATE_STREAM: begin

                    spectrum_valid <= 1'b1;


                    spectrum_out[31:16] <=
                        phase_mem[stream_counter];

                    spectrum_out[15:0] <=
                        magnitude_mem[stream_counter];


                    if (stream_counter == FRAME_SIZE-1) begin

                        state <= STATE_WAIT;

                    end

                    else begin

                        stream_counter <=
                            stream_counter + 1'b1;

                    end

                end


                // =================================================
                // WAIT FOR TRANSFORM
                // =================================================

                STATE_WAIT: begin

                    if (transform_done) begin

                        bin_counter <= 10'd0;

                        max_magnitude <= 16'd0;

                        current_peak_bin <= 10'd0;

                        state <= STATE_RECEIVE;

                    end

                end


                default: begin

                    state <= STATE_RECEIVE;

                end

            endcase

        end

    end

endmodule