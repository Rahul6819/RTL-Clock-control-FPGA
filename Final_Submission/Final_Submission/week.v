`timescale 1ns/1ps

module top_multiclk_fifo #(
    parameter DATA_W = 8,
    parameter DEPTH  = 1024
)(
    input  wire              sys_clk,
    input  wire              sys_rstn,

    // Clock enable pulses
    input  wire [6:0]        clk_enable,

    // Write side
    input  wire [6:0]        data_valid,
    input  wire [7*DATA_W-1:0] data_in,

    // Read side
    input  wire [2:0]        sel,
    input  wire              rd_en,

    // Outputs (selected FIFO)
    output wire [DATA_W-1:0] dout,
    output wire              empty,
    output wire              full,

    // -------- Day 5 Telemetry Outputs --------
    output wire [6:0]        overflow,
    output wire [6:0]        underflow,

    output wire [7*32-1:0]   clk_edge_count
);

    // ---------------------------------------------------------
    // Unpack input data
    // ---------------------------------------------------------
    wire [DATA_W-1:0] data_in_arr [6:0];
    genvar i;
    generate
        for (i = 0; i < 7; i = i + 1) begin : UNPACK
            assign data_in_arr[i] = data_in[(i+1)*DATA_W-1 -: DATA_W];
        end
    endgenerate

    // ---------------------------------------------------------
    // FIFO storage
    // ---------------------------------------------------------
    localparam ADDR_W = $clog2(DEPTH);

    reg [DATA_W-1:0] mem [6:0][0:DEPTH-1];
    reg [ADDR_W:0]   wr_ptr [6:0];
    reg [ADDR_W:0]   rd_ptr [6:0];

    wire [6:0] fifo_empty;
    wire [6:0] fifo_full;

    // ---------------------------------------------------------
    // Write / Read logic + error detection
    // ---------------------------------------------------------
    generate
        for (i = 0; i < 7; i = i + 1) begin : FIFO_LOGIC

            // Overflow / Underflow pulses
            assign overflow[i]  = clk_enable[i] && data_valid[i] && fifo_full[i];
            assign underflow[i] = (sel == i) && rd_en && fifo_empty[i];

            always @(posedge sys_clk or negedge sys_rstn) begin
                if (!sys_rstn) begin
                    wr_ptr[i] <= 0;
                    rd_ptr[i] <= 0;
                end else begin
                    // WRITE
                    if (clk_enable[i] && data_valid[i] && !fifo_full[i]) begin
                        mem[i][wr_ptr[i][ADDR_W-1:0]] <= data_in_arr[i];
                        wr_ptr[i] <= wr_ptr[i] + 1'b1;
                    end

                    // READ (only selected FIFO)
                    if ((sel == i) && rd_en && !fifo_empty[i]) begin
                        rd_ptr[i] <= rd_ptr[i] + 1'b1;
                    end
                end
            end

            assign fifo_empty[i] =
                (wr_ptr[i] == rd_ptr[i]);

            assign fifo_full[i]  =
                (wr_ptr[i][ADDR_W] != rd_ptr[i][ADDR_W]) &&
                (wr_ptr[i][ADDR_W-1:0] == rd_ptr[i][ADDR_W-1:0]);

        end
    endgenerate

    // ---------------------------------------------------------
    // Output MUX (selected FIFO only)
    // ---------------------------------------------------------
    assign dout  = mem[sel][rd_ptr[sel][ADDR_W-1:0]];
    assign empty = fifo_empty[sel];
    assign full  = fifo_full[sel];

    // ---------------------------------------------------------
    // Clock edge counters
    // ---------------------------------------------------------
    reg [31:0] clk_counter [6:0];

    generate
        for (i = 0; i < 7; i = i + 1) begin : CLK_COUNTERS
            always @(posedge sys_clk or negedge sys_rstn) begin
                if (!sys_rstn)
                    clk_counter[i] <= 32'd0;
                else if (clk_enable[i])
                    clk_counter[i] <= clk_counter[i] + 1'b1;
            end

            assign clk_edge_count[(i+1)*32-1 -: 32] = clk_counter[i];
        end
    endgenerate

endmodule
