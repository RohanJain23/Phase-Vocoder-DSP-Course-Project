`timescale 1ns / 1ps

module tb_testing_designs_wrapper;

    // ============================================================
    // CLOCK / RESET
    // ============================================================

    reg clk_in1;
    reg reset;

    // ============================================================
    // FINAL OUTPUT
    // ============================================================

    wire [31:0] m_axis_dout_tdata;
    wire        m_axis_dout_tvalid;

    // ============================================================
    // CONFIGURATION INTERFACE
    // ============================================================

    wire [15:0] s_axis_config_tdata;
    wire        s_axis_config_tvalid;
    reg         s_axis_config_tready;

    // ============================================================
    // FILE / COUNTER
    // ============================================================

    integer mem_file;
    integer sample_count;

    reg simulation_done;

    // ============================================================
    // DUT
    // ============================================================

    testing_designs_wrapper dut (
        .clk_in1              (clk_in1),
        .m_axis_dout_tdata    (m_axis_dout_tdata),
        .m_axis_dout_tvalid   (m_axis_dout_tvalid),
        .reset                (reset),
        .s_axis_config_tdata  (s_axis_config_tdata),
        .s_axis_config_tready (s_axis_config_tready),
        .s_axis_config_tvalid (s_axis_config_tvalid)
    );

    // ============================================================
    // 100 MHz CLOCK
    // ============================================================

    initial begin
        clk_in1 = 1'b0;

        forever begin
            #5 clk_in1 = ~clk_in1;
        end
    end

    // ============================================================
    // INITIALIZATION
    // ============================================================

    initial begin

        sample_count   = 0;
        simulation_done = 1'b0;

        mem_file = $fopen(
            "cordic2_output.mem",
            "w"
        );

        if (mem_file == 0) begin

            $display("==============================================");
            $display("ERROR: Could not open cordic2_output.mem");
            $display("==============================================");

            $finish;

        end

        $display("==============================================");
        $display("cordic2_output.mem opened successfully");
        $display("==============================================");

        reset = 1'b1;

        s_axis_config_tready = 1'b0;

        repeat (10) @(posedge clk_in1);

        reset = 1'b0;

        $display("==============================================");
        $display("RESET RELEASED");
        $display("TIME = %0t ns", $time);
        $display("==============================================");

    end

    // ============================================================
    // CONFIGURATION HANDSHAKE
    //
    // Accept the configuration generated internally.
    // ============================================================

    always @(posedge clk_in1) begin

        if (reset) begin

            s_axis_config_tready <= 1'b0;

        end

        else begin

            if (s_axis_config_tvalid) begin

                s_axis_config_tready <= 1'b1;

                $display(
                    "CONFIG DATA=%04h TIME=%0t",
                    s_axis_config_tdata,
                    $time
                );

            end

            else begin

                s_axis_config_tready <= 1'b0;

            end

        end

    end

    // ============================================================
    // CAPTURE FINAL OUTPUT
    //
    // The internal design performs:
    //
    // harmonic.mem
    //     ?
    // mem_reader
    //     ?
    // FFT
    //     ?
    // CORDIC #1
    //     ?
    // spectral_analysis
    //     ?
    // spectral_transform
    //     ?
    // spectrum_to_cordic
    //     ?
    // CORDIC #2
    //     ?
    // m_axis_dout_tdata
    //
    // ============================================================

    always @(posedge clk_in1) begin

        if (!simulation_done &&
            m_axis_dout_tvalid) begin

            $fdisplay(
                mem_file,
                "%08h",
                m_axis_dout_tdata
            );

            $display(
                "OUTPUT SAMPLE=%0d DATA=%08h TIME=%0t",
                sample_count,
                m_axis_dout_tdata,
                $time
            );

            sample_count = sample_count + 1;

            if (sample_count == 1024) begin

                simulation_done = 1'b1;

                $display("==============================================");
                $display("1024 OUTPUT SAMPLES CAPTURED");
                $display("==============================================");

                $fclose(mem_file);

                $display("cordic2_output.mem closed.");
                $display("Simulation finished.");

                $finish;

            end

        end

    end

    // ============================================================
    // TIMEOUT PROTECTION
    // ============================================================

    initial begin

        #20_000_000;

        if (!simulation_done) begin

            $display("==============================================");
            $display("ERROR: TIMEOUT");
            $display(
                "Samples captured = %0d",
                sample_count
            );
            $display("==============================================");

            $fclose(mem_file);

            $finish;

        end

    end

endmodule