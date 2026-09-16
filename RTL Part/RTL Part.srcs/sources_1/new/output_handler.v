module audio_output_handler (
    input wire        clk,
    input wire        reset_n,

    // =========================================================
    // FIFO READ SIDE
    // =========================================================

    input wire [15:0] fifo_dout,
    input wire        fifo_empty,
    output reg        fifo_rd_en,

    // =========================================================
    // AUDIO OUTPUT
    // =========================================================

    output reg signed [15:0] audio_sample,
    output reg               audio_valid,
    input wire                audio_ready
);

    always @(posedge clk) begin

        if (!reset_n) begin

            fifo_rd_en  <= 1'b0;
            audio_sample <= 16'sd0;
            audio_valid <= 1'b0;

        end

        else begin

            fifo_rd_en <= 1'b0;

            // -------------------------------------------------
            // FIFO contains data and downstream can accept it
            // -------------------------------------------------

            if (!fifo_empty && audio_ready) begin

                fifo_rd_en <= 1'b1;

            end

            // -------------------------------------------------
            // FWFT FIFO:
            //
            // dout is already available when !empty.
            // -------------------------------------------------

            if (!fifo_empty) begin

                audio_sample <= fifo_dout;
                audio_valid  <= 1'b1;

            end

            else begin

                audio_valid <= 1'b0;

            end

        end

    end

endmodule