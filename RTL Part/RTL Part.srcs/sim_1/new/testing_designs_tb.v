`timescale 1ns / 1ps

module tb_testing_designs_wrapper;

    reg clk_in1;
    reg reset;

    wire [31:0] m_axis_data_tdata;
    wire        m_axis_data_tlast;
    wire        m_axis_data_tvalid;

    wire [31:0] m_axis_tdata;
    wire        m_axis_tlast;
    wire        m_axis_tvalid;

    wire [15:0] s_axis_config_tdata;
    wire        s_axis_config_tready;
    wire        s_axis_config_tvalid;
    wire        s_axis_config_tvalid_1;
    wire        s_axis_data_tready;

    // ============================================================
    // DUT
    // ============================================================

    testing_designs_wrapper dut (
        .clk_in1(clk_in1),
        .m_axis_data_tdata(m_axis_data_tdata),
        .m_axis_data_tlast(m_axis_data_tlast),
        .m_axis_data_tvalid(m_axis_data_tvalid),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tlast(m_axis_tlast),
        .m_axis_tvalid(m_axis_tvalid),
        .reset(reset),
        .s_axis_config_tdata(s_axis_config_tdata),
        .s_axis_config_tready(s_axis_config_tready),
        .s_axis_config_tvalid(s_axis_config_tvalid),
        .s_axis_config_tvalid_1(s_axis_config_tvalid_1),
        .s_axis_data_tready(s_axis_data_tready)
    );

    // ============================================================
    // 100 MHz CLOCK
    // ============================================================

    initial begin
        clk_in1 = 1'b0;
        forever #5 clk_in1 = ~clk_in1;
    end

    // ============================================================
    // RESET / SIMULATION
    // ============================================================

    initial begin
        reset = 1'b1;

        repeat (10) @(posedge clk_in1);

        reset = 1'b0;

        #100000;

        $finish;
    end

    // ============================================================
    // MONITOR OUTPUTS
    // ============================================================

    always @(posedge clk_in1) begin

        if (m_axis_data_tvalid) begin
            $display(
                "FFT DATA  : %h | TLAST = %b",
                m_axis_data_tdata,
                m_axis_data_tlast
            );
        end

        if (m_axis_tvalid) begin
            $display(
                "AXIS DATA : %h | TLAST = %b",
                m_axis_tdata,
                m_axis_tlast
            );
        end

    end

endmodule