module mem_reader #(
    parameter SAMPLE_WIDTH = 16,
    parameter FRAME_SIZE   = 1024,
    parameter NUM_SAMPLES  = 1000000,
    parameter MEM_FILE = "harmonic.mem"
)(
    input  wire clk,
    input  wire reset,

    // -----------------------------------------
    // AXI4-Stream output to FFT
    // -----------------------------------------
    output reg [2*SAMPLE_WIDTH-1:0] m_axis_tdata,
    output reg                      m_axis_tvalid,
    input  wire                     m_axis_tready,
    output reg                      m_axis_tlast
);

    // -----------------------------------------
    // Memory
    // -----------------------------------------
    reg signed [SAMPLE_WIDTH-1:0] mem [0:NUM_SAMPLES-1];

    initial begin
        $readmemh(MEM_FILE, mem);
    end

    // -----------------------------------------
    // Address counter
    // -----------------------------------------
    integer address;

    // -----------------------------------------
    // Main logic
    // -----------------------------------------
    always @(posedge clk) begin

        if (reset) begin

            address        <= 0;
            m_axis_tdata   <= 0;
            m_axis_tvalid  <= 0;
            m_axis_tlast   <= 0;

        end

        else begin

            // =====================================================
            // Start streaming
            // =====================================================
            if (!m_axis_tvalid && address < NUM_SAMPLES) begin

                // Real part
                m_axis_tdata[SAMPLE_WIDTH-1:0]
                    <= mem[address];

                // Imaginary part = 0
                m_axis_tdata[2*SAMPLE_WIDTH-1:SAMPLE_WIDTH]
                    <= 0;

                m_axis_tvalid <= 1'b1;

                // TLAST on last sample of every frame
                if ((address % FRAME_SIZE) == FRAME_SIZE-1)
                    m_axis_tlast <= 1'b1;
                else
                    m_axis_tlast <= 1'b0;

            end

            // =====================================================
            // AXI transfer occurred
            // =====================================================
            else if (m_axis_tvalid && m_axis_tready) begin

                // Move to next sample
                address <= address + 1;

                // -------------------------------------------------
                // More samples available
                // -------------------------------------------------
                if (address + 1 < NUM_SAMPLES) begin

                    // Load next real sample immediately
                    m_axis_tdata[SAMPLE_WIDTH-1:0]
                        <= mem[address + 1];

                    // Imaginary part = 0
                    m_axis_tdata[2*SAMPLE_WIDTH-1:SAMPLE_WIDTH]
                        <= 0;

                    // Keep VALID asserted
                    // This allows one sample every clock
                    m_axis_tvalid <= 1'b1;

                    // TLAST for next sample
                    if (((address + 1) % FRAME_SIZE) == FRAME_SIZE-1)
                        m_axis_tlast <= 1'b1;
                    else
                        m_axis_tlast <= 1'b0;

                end

                // -------------------------------------------------
                // No more samples
                // -------------------------------------------------
                else begin

                    m_axis_tvalid <= 1'b0;
                    m_axis_tlast  <= 1'b0;

                end
            end

        end
    end

endmodule