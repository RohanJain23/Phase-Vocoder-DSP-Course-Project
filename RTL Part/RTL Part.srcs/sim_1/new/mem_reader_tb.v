`timescale 1ns / 1ps

module tb_mem_reader;

    // ------------------------------------------------
    // Parameters
    // ------------------------------------------------
    parameter SAMPLE_WIDTH = 16;
    parameter FRAME_SIZE   = 1024;
    parameter NUM_SAMPLES  = 4096;

    // ------------------------------------------------
    // Signals
    // ------------------------------------------------
    reg clk;
    reg reset;

    wire [2*SAMPLE_WIDTH-1:0] m_axis_tdata;
    wire                      m_axis_tvalid;
    reg                       m_axis_tready;
    wire                      m_axis_tlast;

    // ------------------------------------------------
    // DUT
    // ------------------------------------------------
    mem_reader #(
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
        .FRAME_SIZE(FRAME_SIZE),
        .NUM_SAMPLES(NUM_SAMPLES),
        .MEM_FILE("sine_test.mem")
    ) dut (
        .clk(clk),
        .reset(reset),

        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast)
    );

    // ------------------------------------------------
    // Clock: 100 MHz
    // ------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------
    // Test
    // ------------------------------------------------
    integer sample_count;
    integer frame_count;

    initial begin

        reset         = 1'b1;
        m_axis_tready = 1'b0;

        sample_count = 0;
        frame_count  = 0;

        // Hold reset for 5 clock cycles
        repeat(5) @(posedge clk);

        reset = 1'b0;

        // Start accepting data
        m_axis_tready = 1'b1;

        // Run long enough for NUM_SAMPLES
        wait(sample_count == NUM_SAMPLES);

        #100;

        $display("========================================");
        $display("TEST COMPLETED");
        $display("Total samples received = %0d", sample_count);
        $display("Total frames received  = %0d", frame_count);
        $display("========================================");

        $finish;
    end

    // ------------------------------------------------
    // Monitor AXI-Stream transfers
    // ------------------------------------------------
    always @(posedge clk) begin

        if (!reset) begin

            if (m_axis_tvalid && m_axis_tready) begin

                // ------------------------------------
                // Display sample information
                // ------------------------------------
                $display(
                    "Sample = %0d | Data = %h | Real = %d | Imag = %d | TLAST = %b",
                    sample_count,
                    m_axis_tdata,
                    $signed(m_axis_tdata[SAMPLE_WIDTH-1:0]),
                    $signed(m_axis_tdata[2*SAMPLE_WIDTH-1:SAMPLE_WIDTH]),
                    m_axis_tlast
                );

                // ------------------------------------
                // Check imaginary part
                // ------------------------------------
                if (m_axis_tdata[2*SAMPLE_WIDTH-1:SAMPLE_WIDTH] !== 0) begin
                    $display("ERROR: Imaginary part is not zero!");
                end

                // ------------------------------------
                // Check TLAST
                // ------------------------------------
                if ((sample_count % FRAME_SIZE) == FRAME_SIZE-1) begin

                    if (m_axis_tlast !== 1'b1) begin
                        $display(
                            "ERROR: TLAST missing at sample %0d",
                            sample_count
                        );
                    end
                    else begin
                        $display(
                            "---- TLAST: End of frame %0d ----",
                            frame_count
                        );
                    end

                    frame_count = frame_count + 1;

                end
                else begin

                    if (m_axis_tlast !== 1'b0) begin
                        $display(
                            "ERROR: Unexpected TLAST at sample %0d",
                            sample_count
                        );
                    end

                end

                sample_count = sample_count + 1;

            end
        end
    end

endmodule