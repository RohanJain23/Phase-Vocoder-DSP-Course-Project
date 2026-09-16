`timescale 1ns / 1ps

module tb_testing_designs_wrapper;

    // ============================================================
    // CLOCK AND RESET
    // ============================================================

    reg clk_in1;
    reg reset;


    // ============================================================
    // IFFT OUTPUT
    // ============================================================

    wire [31:0] m_axis_data_tdata;
    wire        m_axis_data_tlast;
    wire        m_axis_data_tvalid;


    // ============================================================
    // FILE HANDLING
    // ============================================================

    integer mem_file;
    integer sample_count;

    reg capture_done;


    // ============================================================
    // DUT
    // ============================================================

    testing_designs_wrapper dut (
        .clk_in1(clk_in1),

        .m_axis_data_tdata(m_axis_data_tdata),
        .m_axis_data_tlast(m_axis_data_tlast),
        .m_axis_data_tvalid(m_axis_data_tvalid),

        .reset(reset)
    );


    // ============================================================
    // 100 MHz CLOCK
    //
    // Period = 10 ns
    // ============================================================

    initial begin

        clk_in1 = 1'b0;

        forever begin
            #5 clk_in1 = ~clk_in1;
        end

    end


    // ============================================================
    // INITIALIZATION + RESET
    // ============================================================

    initial begin

        sample_count = 0;
        capture_done = 1'b0;


        // --------------------------------------------------------
        // Open output memory file
        // --------------------------------------------------------

        mem_file = $fopen("ifft_output.mem", "w");

        if (mem_file == 0) begin

            $display("ERROR: Could not open ifft_output.mem");
            $finish;

        end


        $display("==============================================");
        $display("IFFT OUTPUT CAPTURE STARTED");
        $display("Output file: ifft_output.mem");
        $display("==============================================");


        // --------------------------------------------------------
        // Apply reset
        // --------------------------------------------------------

        reset = 1'b1;


        // Hold reset for 10 clock cycles

        repeat (10) @(posedge clk_in1);


        // Release reset

        reset = 1'b0;


        $display("==============================================");
        $display("RESET RELEASED");
        $display("==============================================");

    end


    // ============================================================
    // CAPTURE IFFT OUTPUT
    //
    // Since your wrapper does not expose a separate output clock,
    // capture using clk_in1.
    // ============================================================

    always @(posedge clk_in1) begin

        if (!capture_done && !reset) begin

            if (m_axis_data_tvalid) begin


                // ------------------------------------------------
                // Write output to .mem
                //
                // Format:
                //
                // [31:16] = Imaginary
                // [15:0]  = Real
                // ------------------------------------------------

                $fdisplay(
                    mem_file,
                    "%08h",
                    m_axis_data_tdata
                );


                // ------------------------------------------------
                // Display output
                // ------------------------------------------------

                $display(
                    "IFFT_OUT SAMPLE=%0d TIME=%0t DATA=%08h TLAST=%b",
                    sample_count,
                    $time,
                    m_axis_data_tdata,
                    m_axis_data_tlast
                );


                // ------------------------------------------------
                // Increment sample count
                // ------------------------------------------------

                sample_count = sample_count + 1;


                // ------------------------------------------------
                // End of complete IFFT frame
                // ------------------------------------------------

                if (m_axis_data_tlast) begin

                    capture_done = 1'b1;


                    $display("==============================================");
                    $display("IFFT FRAME COMPLETE");
                    $display(
                        "TOTAL OUTPUT SAMPLES = %0d",
                        sample_count
                    );
                    $display("==============================================");


                    // Close output file

                    $fclose(mem_file);


                    $display("ifft_output.mem closed.");
                    $display("Simulation finished.");


                    // Stop simulation

                    $finish;

                end

            end

        end

    end


    // ============================================================
    // SAFETY TIMEOUT
    //
    // Prevent infinite simulation if TLAST never arrives.
    // ============================================================

    initial begin

        #10000000;

        if (!capture_done) begin

            $display("==============================================");
            $display("ERROR: SIMULATION TIMEOUT");
            $display(
                "Captured samples = %0d",
                sample_count
            );
            $display("TLAST was never received.");
            $display("==============================================");

            $fclose(mem_file);

            $finish;

        end

    end


endmodule