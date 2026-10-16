`timescale 1ns / 1ps

module async_fifo # (
    // Data width (e.g., 8, 16, 32)
    parameter DATA_W = 8,
    // Depth of the FIFO (must be a power of 2 for this pointer scheme)
    parameter DEPTH  = 16
) (
    input  wire              wr_clk,        // Write domain clock
    input  wire              rd_clk,        // Read domain clock
    input  wire              rst,           // Asynchronous Reset (active high)
    input  wire              wr_en,         // Write enable
    input  wire [DATA_W-1:0] din,           // Data in
    input  wire              rd_en,         // Read enable
    output reg  [DATA_W-1:0] dout,          // Data out
    output wire              empty,         // FIFO empty flag
    output wire              full           // FIFO full flag
);

    // Address width: log2(DEPTH)
    localparam ADDR_W = $clog2(DEPTH);
    // Pointer width: ADDR_W + 1 (for full/empty detection)
    localparam PTR_W = ADDR_W + 1;

    // Internal memory array
    reg [DATA_W-1:0] mem [0:DEPTH-1];

    // Binary Pointers (for local address generation and increment)
    reg [PTR_W-1:0] wr_ptr_bin, rd_ptr_bin;

    // Gray Code Pointers (for safe crossing of clock domains)
    reg [PTR_W-1:0] wr_ptr_gray, rd_ptr_gray;
    wire [PTR_W-1:0] wr_ptr_next_gray, rd_ptr_next_gray;

    // Synchronized Gray Pointers (from opposite clock domain)
    wire [PTR_W-1:0] rd_ptr_sync_gray, wr_ptr_sync_gray;

    // =======================================================================
    // 1. Write Side Logic (Driven by wr_clk)
    // =======================================================================

    // A. Write Pointer and Memory Update
    always @(posedge wr_clk or posedge rst) begin
        if (rst) begin
            wr_ptr_bin <= {PTR_W{1'b0}};
            wr_ptr_gray <= {PTR_W{1'b0}};
        end else if (wr_en && !full) begin
            // Write data to memory at the current address
            mem[wr_ptr_bin[ADDR_W-1:0]] <= din;
            // Update binary pointer
            wr_ptr_bin <= wr_ptr_bin + 1'b1;
            // Update Gray code pointer
            wr_ptr_gray <= wr_ptr_next_gray;
        end
    end

    // Binary to Gray conversion for the next pointer value
    assign wr_ptr_next_gray = (wr_ptr_bin + 1'b1) ^ ((wr_ptr_bin + 1'b1) >> 1);

    // =======================================================================
    // 2. Read Side Logic (Driven by rd_clk)
    // =======================================================================

    // A. Read Pointer and Data Out
    always @(posedge rd_clk or posedge rst) begin
        if (rst) begin
            rd_ptr_bin <= {PTR_W{1'b0}};
            rd_ptr_gray <= {PTR_W{1'b0}};
            dout <= {DATA_W{1'b0}};
        end else if (rd_en && !empty) begin
            // Read data from memory at the current address (before increment)
            dout <= mem[rd_ptr_bin[ADDR_W-1:0]];
            // Update binary pointer
            rd_ptr_bin <= rd_ptr_bin + 1'b1;
            // Update Gray code pointer
            rd_ptr_gray <= rd_ptr_next_gray;
        end
    end

    // Binary to Gray conversion for the next pointer value
    assign rd_ptr_next_gray = (rd_ptr_bin + 1'b1) ^ ((rd_ptr_bin + 1'b1) >> 1);

    // =======================================================================
    // 3. Clock Domain Crossing (CDC) Synchronization
    // =======================================================================

    // Synchronize Write Gray Pointer (wr_ptr_gray) to Read Clock (rd_clk)
    // Three-flop synchronizer for robustness
    reg [PTR_W-1:0] wr_ptr_sync_r1, wr_ptr_sync_r2;
    always @(posedge rd_clk or posedge rst) begin
        if (rst) begin
            wr_ptr_sync_r1 <= {PTR_W{1'b0}};
            wr_ptr_sync_r2 <= {PTR_W{1'b0}};
        end else begin
            wr_ptr_sync_r1 <= wr_ptr_gray;
            wr_ptr_sync_r2 <= wr_ptr_sync_r1;
        end
    end
    assign wr_ptr_sync_gray = wr_ptr_sync_r2;

    // Synchronize Read Gray Pointer (rd_ptr_gray) to Write Clock (wr_clk)
    // Three-flop synchronizer for robustness
    reg [PTR_W-1:0] rd_ptr_sync_r1, rd_ptr_sync_r2;
    always @(posedge wr_clk or posedge rst) begin
        if (rst) begin
            rd_ptr_sync_r1 <= {PTR_W{1'b0}};
            rd_ptr_sync_r2 <= {PTR_W{1'b0}};
        end else begin
            rd_ptr_sync_r1 <= rd_ptr_gray;
            rd_ptr_sync_r2 <= rd_ptr_sync_r1;
        end
    end
    assign rd_ptr_sync_gray = rd_ptr_sync_r2;

    // =======================================================================
    // 4. Full and Empty Flag Generation
    // =======================================================================

    // FULL: Checks if the next (incremented) write pointer is equal to the synchronized read pointer.
    // The MSB (overflow bit) and the next two bits are inverted compared to empty.
    assign full = (wr_ptr_next_gray[PTR_W-1] != rd_ptr_sync_gray[PTR_W-1]) &&
                  (wr_ptr_next_gray[PTR_W-2] == rd_ptr_sync_gray[PTR_W-2]) &&
                  (wr_ptr_next_gray[PTR_W-3:0] == rd_ptr_sync_gray[PTR_W-3:0]);

    // EMPTY: Checks if the current read pointer is equal to the synchronized write pointer.
    assign empty = (rd_ptr_gray == wr_ptr_sync_gray);

endmodule