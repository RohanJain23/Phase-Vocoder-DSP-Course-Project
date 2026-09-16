`timescale 1ns / 1ps

module tb_design_1_wrapper;

    reg clk;
    reg reset;

    wire [31:0] m_axis_data_tdata;
    wire        m_axis_data_tvalid;

    // DUT
    design_1_wrapper dut (
        .clk(clk),
        .m_axis_data_tdata(m_axis_data_tdata),
        .m_axis_data_tvalid(m_axis_data_tvalid),
        .reset(reset)
    );

    // 100 MHz clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Reset and run
    initial begin
        reset = 1;

        repeat(10) @(posedge clk);

        reset = 0;

        // Run long enough to observe FFT output
        repeat(2000) @(posedge clk);

        $finish;
    end

    // Display FFT output
    always @(posedge clk) begin
        if (m_axis_data_tvalid) begin
            $display(
                "Time=%0t  FFT_DATA=%h",
                $time,
                m_axis_data_tdata
            );
        end
    end

endmodule