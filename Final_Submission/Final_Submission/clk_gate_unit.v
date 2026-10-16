`timescale 1ns / 1ps

module clk_gate_unit #(
    parameter CHANNELS = 7
)(
    input  wire [CHANNELS-1:0] gate_mask,     // 1 = enable channel
    input  wire                global_en,     // master enable from FSM
    input  wire [CHANNELS-1:0] raw_en_in,     // pulses from freq generators
    output wire [CHANNELS-1:0] gated_en_out   // pulses to FIFOs
);

    // Clock-enable style gating (FPGA safe)
    assign gated_en_out = raw_en_in &
                          gate_mask &
                          {CHANNELS{global_en}};

endmodule
