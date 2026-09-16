`timescale 1ns / 1ps

module tb_fft_test_bd_wrapper;

    reg clk;
    reg reset;

    wire [31:0] m_axis_data_tdata_0;
    wire        m_axis_data_tlast;
    wire        m_axis_data_tvalid;

    // DUT
    fft_test_bd_wrapper dut (
        .clk(clk),
        .m_axis_data_tdata_0(m_axis_data_tdata_0),
        .m_axis_data_tlast(m_axis_data_tlast),
        .m_axis_data_tvalid(m_axis_data_tvalid),
        .reset(reset)
    );

    // 100 MHz clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Reset and run simulation
    initial begin
        reset = 1'b1;

        // Hold reset for 10 clock cycles
        repeat(10) @(posedge clk);

        // Release reset
        reset = 1'b0;

        // Run for enough time to observe FFT output
        #100000;

        $finish;
    end

    // Display FFT outputs
    always @(posedge clk) begin
        if (m_axis_data_tvalid) begin
            $display(
                "TIME=%0t | FFT_DATA=%h | TLAST=%b",
                $time,
                m_axis_data_tdata_0,
                m_axis_data_tlast
            );
        end
    end

endmodule