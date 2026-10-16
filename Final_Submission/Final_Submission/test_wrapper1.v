`timescale 1ns / 1ps

module Integrated_clk_ctrl_slave_lite_v1_0_S00_AXI #
(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 10,

    parameter DATA_W      = 32,
    parameter CNT_W       = 32,
    parameter FIFO_DEPTH  = 1024
)
(
    // AXI signals
    input  wire                          S_AXI_ACLK,
    input  wire                          S_AXI_ARESETN,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input  wire                          S_AXI_AWVALID,
    output reg                           S_AXI_AWREADY,
    input  wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  wire                          S_AXI_WVALID,
    output reg                           S_AXI_WREADY,
    output reg  [1:0]                    S_AXI_BRESP,
    output reg                           S_AXI_BVALID,
    input  wire                          S_AXI_BREADY,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input  wire                          S_AXI_ARVALID,
    output reg                           S_AXI_ARREADY,
    output reg  [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output reg  [1:0]                    S_AXI_RRESP,
    output reg                           S_AXI_RVALID,
    input  wire                          S_AXI_RREADY
);

    //---------------------------------------------------------
    // AXI Registers
    //---------------------------------------------------------
    reg [31:0] slv_reg0;
    reg [31:0] slv_reg12, slv_reg13, slv_reg14, slv_reg15;
    reg [31:0] slv_reg16, slv_reg17, slv_reg18;
    reg [31:0] slv_reg11;

    //---------------------------------------------------------
    // Core wires
    //---------------------------------------------------------
    wire [3:0]         fsm_status_w;
    wire               empty_w, full_w;
    wire [7*CNT_W-1:0] counters_w;
    wire [DATA_W-1:0]  fifo_dout_w;
    wire [13:0]        sticky_telemetry_out;

    //---------------------------------------------------------
    // Core instantiation (UPDATED)
    //---------------------------------------------------------
    clock_control_core #(
        .DATA_W(DATA_W),
        .FIFO_DEPTH(FIFO_DEPTH),
        .CNT_W(CNT_W)
    ) core_inst (
        .sys_clk            (S_AXI_ACLK),
        .sys_rstn           (S_AXI_ARESETN),

        .freq_change_req_in (slv_reg0[0]),
        .sel_in             (slv_reg0[4:2]),
        .gate_mask_in       (slv_reg0[14:8]),   // <<< NEW

        .divisors_in        ({slv_reg18, slv_reg17, slv_reg16,
                              slv_reg15, slv_reg14, slv_reg13, slv_reg12}),

        .data_valid         (7'b0),
        .data_in            ({(7*DATA_W){1'b0}}),
        .rd_en              (S_AXI_ARREADY && S_AXI_ARVALID &&
                             (S_AXI_ARADDR[C_S_AXI_ADDR_WIDTH-1:2] == 5'h0A)),

        .dout               (fifo_dout_w),
        .empty              (empty_w),
        .full               (full_w),
        .fsm_status_out     (fsm_status_w),
        .clk_edge_count_out (counters_w),
        .sticky_telemetry_out (sticky_telemetry_out)
    );

endmodule
