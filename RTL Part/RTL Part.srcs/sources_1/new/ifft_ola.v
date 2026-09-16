module ifft_ola #(
    parameter FRAME_SIZE  = 1024,
    parameter HOP_SIZE    = 512,
    parameter IFFT_WIDTH  = 16,
    parameter OLA_WIDTH   = 18,
    parameter AUDIO_WIDTH = 16
)(
    input wire clk,
    input wire reset_n,

    // =========================================================
    // IFFT AXI4-STREAM OUTPUT
    //
    // [31:16] = imaginary
    // [15:0]  = real
    // =========================================================

    input wire [31:0] s_axis_tdata,
    input wire        s_axis_tvalid,
    output wire       s_axis_tready,
    input wire        s_axis_tlast,

    // =========================================================
    // FIFO WRITE INTERFACE
    // FIFO DATA WIDTH = 16
    // =========================================================

    output reg [AUDIO_WIDTH-1:0] fifo_din,
    output reg                   fifo_wr_en,
    input wire                   fifo_full,

    // =========================================================
    // STATUS
    // =========================================================

    output reg frame_done
);

    // =========================================================
    // IFFT REAL COMPONENT
    // =========================================================

    wire signed [IFFT_WIDTH-1:0] ifft_real;

    assign ifft_real = s_axis_tdata[15:0];

    // =========================================================
    // SIGN EXTEND IFFT OUTPUT TO OLA WIDTH
    // 16-bit -> 18-bit
    // =========================================================

    wire signed [OLA_WIDTH-1:0] current_sample;

    assign current_sample =
        {{(OLA_WIDTH-IFFT_WIDTH){ifft_real[IFFT_WIDTH-1]}},
         ifft_real};

    // =========================================================
    // OVERLAP MEMORY
    //
    // Stores second half of previous IFFT frame.
    //
    // 512 samples × 18 bits
    // =========================================================

    reg signed [OLA_WIDTH-1:0]
        overlap_mem [0:HOP_SIZE-1];

    // =========================================================
    // SAMPLE COUNTER
    // =========================================================

    reg [9:0] sample_counter;

    // =========================================================
    // FIRST FRAME FLAG
    // =========================================================

    reg have_previous_frame;

    // =========================================================
    // FIFO BACKPRESSURE
    //
    // First half produces FIFO samples.
    // Therefore we cannot accept another IFFT sample when
    // the FIFO is full.
    //
    // Second half only fills overlap memory.
    // =========================================================

    assign s_axis_tready =
        (sample_counter < HOP_SIZE) ?
        !fifo_full :
        1'b1;

    // =========================================================
    // SATURATION
    //
    // Convert 18-bit OLA result to signed 16-bit audio.
    // =========================================================

    function [15:0] saturate_18_to_16;
        input signed [17:0] value;

        begin

            if (value > 18'sd32767)
                saturate_18_to_16 = 16'h7FFF;

            else if (value < -18'sd32768)
                saturate_18_to_16 = 16'h8000;

            else
                saturate_18_to_16 = value[15:0];

        end
    endfunction

    // =========================================================
    // MAIN PROCESS
    // =========================================================

    always @(posedge clk) begin

        if (!reset_n) begin

            sample_counter      <= 10'd0;
            have_previous_frame <= 1'b0;

            fifo_din            <= 16'd0;
            fifo_wr_en          <= 1'b0;

            frame_done          <= 1'b0;

        end

        else begin

            // -------------------------------------------------
            // Defaults
            // -------------------------------------------------

            fifo_wr_en <= 1'b0;
            frame_done <= 1'b0;

            // -------------------------------------------------
            // Receive IFFT sample
            // -------------------------------------------------

            if (s_axis_tvalid && s_axis_tready) begin

                // =================================================
                // FIRST 512 SAMPLES
                // =================================================

                if (sample_counter < HOP_SIZE) begin

                    if (!have_previous_frame) begin

                        // -----------------------------------------
                        // First frame
                        // Nothing to overlap with.
                        // -----------------------------------------

                        fifo_din <=
                            saturate_18_to_16(current_sample);

                    end

                    else begin

                        // -----------------------------------------
                        // Add previous frame's second half
                        // to current frame's first half.
                        // -----------------------------------------

                        fifo_din <=
                            saturate_18_to_16(
                                overlap_mem[sample_counter]
                                + current_sample
                            );

                    end

                    fifo_wr_en <= 1'b1;

                end

                // =================================================
                // LAST 512 SAMPLES
                // =================================================

                else begin

                    // Store current frame's second half
                    // for overlap with the next frame.

                    overlap_mem[sample_counter - HOP_SIZE]
                        <= current_sample;

                end

                // =================================================
                // END OF 1024-SAMPLE FRAME
                // =================================================

                if (sample_counter == FRAME_SIZE-1) begin

                    sample_counter      <= 10'd0;
                    have_previous_frame <= 1'b1;

                    frame_done <= 1'b1;

                end

                else begin

                    sample_counter <= sample_counter + 1'b1;

                end

            end

        end

    end

endmodule