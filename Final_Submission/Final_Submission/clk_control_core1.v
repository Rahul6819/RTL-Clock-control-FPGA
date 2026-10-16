`timescale 1ns/1ps

module clock_control_core #
(
    parameter DATA_W     = 32,
    parameter FIFO_DEPTH = 1024,
    parameter CNT_W      = 32
)
(
    input  wire sys_clk,
    input  wire sys_rstn,

    // AXI control inputs
    input  wire freq_change_req_in,
    input  wire [2:0] sel_in,
    input  wire [6:0] gate_mask_in,     // <<< NEW (from AXI reg)

    // Dynamic divisors
    input  wire [7*32-1:0] divisors_in,

    // External inputs
    input  wire [6:0] data_valid,
    input  wire [7*DATA_W-1:0] data_in,
    input  wire rd_en,

    // Outputs
    output wire [DATA_W-1:0]  dout,
    output wire               empty,
    output wire               full,
    output wire [3:0]         fsm_status_out,
    output wire [7*CNT_W-1:0] clk_edge_count_out,

    // ---------------- Day 5 Telemetry Output ----------------
    output wire [13:0]        sticky_telemetry_out
);

    // ---------------------------------------------------------
    // FSM signals
    // ---------------------------------------------------------
    wire fsm_done;
    wire hold_fifos;
    wire freq_update_en;
    wire fsm_error;

    assign fsm_status_out = {
        fsm_error,
        freq_update_en,
        hold_fifos,
        fsm_done
    };

    fsm_clk_ctrl fsm_inst (
        .clk              (sys_clk),
        .rstn             (sys_rstn),
        .freq_change_req  (freq_change_req_in),
        .all_fifos_empty  (empty),
        .hold_fifos       (hold_fifos),
        .freq_update_en   (freq_update_en),
        .done             (fsm_done),
        .fsm_error        (fsm_error)
    );

    // ---------------------------------------------------------
    // Clock enable generators (7 channels)
    // ---------------------------------------------------------
    wire [6:0] raw_pulses;
    wire [6:0] gated_pulses;

    genvar i;
    generate
        for (i = 0; i < 7; i = i + 1) begin : GEN_CLK_EN
            Freq freq_inst (
                .clk     (sys_clk),
                .rst     (~sys_rstn),
                .divisor (divisors_in[(i+1)*32-1 : i*32]),
                .clk_en  (raw_pulses[i])
            );
        end
    endgenerate

    // ---------------------------------------------------------
    // Clock Gating Unit (NEW)
    // ---------------------------------------------------------
    clk_gate_unit #(
        .CHANNELS(7)
    ) clk_gate_inst (
        .gate_mask    (gate_mask_in),
        .global_en    (~hold_fifos),   // FSM override
        .raw_en_in    (raw_pulses),
        .gated_en_out (gated_pulses)
    );

    // ---------------------------------------------------------
    // FIFO error telemetry signals (Day 5)
    // ---------------------------------------------------------
    wire [6:0] overflow_vec;
    wire [6:0] underflow_vec;

    reg  [6:0] overflow_sticky;
    reg  [6:0] underflow_sticky;

    // ---------------------------------------------------------
    // FIFO system
    // ---------------------------------------------------------
    top_multiclk_fifo #
    (
        .DATA_W (DATA_W),
        .DEPTH  (FIFO_DEPTH)
    ) fifo_inst (
        .sys_clk        (sys_clk),
        .sys_rstn       (sys_rstn),
        .clk_enable     (gated_pulses),   // <<< UPDATED

        .data_valid     (data_valid),
        .data_in        (data_in),
        .sel            (sel_in),
        .rd_en          (rd_en),

        .dout           (dout),
        .empty          (empty),
        .full           (full),

        .overflow       (overflow_vec),
        .underflow      (underflow_vec),

        .clk_edge_count (clk_edge_count_out)
    );

    // ---------------------------------------------------------
    // Sticky telemetry logic (Day 5)
    // ---------------------------------------------------------
    always @(posedge sys_clk or negedge sys_rstn) begin
        if (!sys_rstn) begin
            overflow_sticky  <= 7'b0;
            underflow_sticky <= 7'b0;

        end else if (freq_change_req_in) begin
            overflow_sticky  <= 7'b0;
            underflow_sticky <= 7'b0;

        end else begin
            overflow_sticky  <= overflow_sticky  | overflow_vec;
            underflow_sticky <= underflow_sticky | underflow_vec;
        end
    end

    // ---------------------------------------------------------
    // Telemetry packing for AXI wrapper
    // ---------------------------------------------------------
    assign sticky_telemetry_out = {
        overflow_sticky,
        underflow_sticky
    };

endmodule
