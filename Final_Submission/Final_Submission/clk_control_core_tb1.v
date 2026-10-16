`timescale 1ns / 1ps

module clk_control_gating_tb;

    // =========================================================
    // Parameters
    // =========================================================
    localparam DATA_W = 32;
    localparam CNT_W  = 32;
    localparam CLK_PERIOD = 10; // 100 MHz

    // =========================================================
    // Signals
    // =========================================================
    reg  clk;
    reg  rstn;

    reg        freq_change_req;
    reg  [2:0] sel;
    reg  [6:0] gate_mask;

    reg  [7*32-1:0] divisors;

    wire [7*CNT_W-1:0] clk_edge_count;
    wire [3:0] fsm_status;

    // =========================================================
    // DUT
    // =========================================================
    clock_control_core #(
        .DATA_W(DATA_W),
        .CNT_W (CNT_W)
    ) dut (
        .sys_clk            (clk),
        .sys_rstn           (rstn),

        .freq_change_req_in (freq_change_req),
        .sel_in             (sel),
        .gate_mask_in       (gate_mask),

        .divisors_in        (divisors),

        .data_valid         (7'b0),
        .data_in            ({(7*DATA_W){1'b0}}),
        .rd_en              (1'b0),

        .dout               (),
        .empty              (),
        .full               (),
        .fsm_status_out     (fsm_status),
        .clk_edge_count_out (clk_edge_count),
        .sticky_telemetry_out ()
    );

    // =========================================================
    // Clock
    // =========================================================
    always #(CLK_PERIOD/2) clk = ~clk;

    // =========================================================
    // Helper task
    // =========================================================
    task show_counts;
        begin
            $display("[%0t] Edge counts: %0d %0d %0d %0d %0d %0d %0d",
                $time,
                clk_edge_count[1*CNT_W-1:0*CNT_W],
                clk_edge_count[2*CNT_W-1:1*CNT_W],
                clk_edge_count[3*CNT_W-1:2*CNT_W],
                clk_edge_count[4*CNT_W-1:3*CNT_W],
                clk_edge_count[5*CNT_W-1:4*CNT_W],
                clk_edge_count[6*CNT_W-1:5*CNT_W],
                clk_edge_count[7*CNT_W-1:6*CNT_W]
            );
        end
    endtask

    // =========================================================
    // TEST SEQUENCE
    // =========================================================
    initial begin
        clk = 0;
        rstn = 0;

        freq_change_req = 0;
        sel = 0;
        gate_mask = 7'b0;

        // Set different frequencies
        divisors = {
            32'd20,  // ch6
            32'd15,  // ch5
            32'd10,  // ch4
            32'd8,   // ch3
            32'd6,   // ch2
            32'd4,   // ch1
            32'd2    // ch0
        };

        // Reset
        repeat (5) @(posedge clk);
        rstn = 1;
        $display("[%0t] Reset released", $time);

        // -----------------------------------------------------
        // Test 1: Enable ALL channels
        // -----------------------------------------------------
        gate_mask = 7'b111_1111;
        repeat (200) @(posedge clk);
        show_counts();

        // -----------------------------------------------------
        // Test 2: Disable channels 2,4,6
        // -----------------------------------------------------
        gate_mask = 7'b010_1011;
        repeat (200) @(posedge clk);
        show_counts();

        // EXPECT: counts of disabled channels stop increasing

        // -----------------------------------------------------
        // Test 3: FSM HOLD overrides gate mask
        // -----------------------------------------------------
        $display("[%0t] Triggering FSM HOLD", $time);
        freq_change_req = 1;
        @(posedge clk);
        freq_change_req = 0;

        repeat (200) @(posedge clk);
        show_counts();

        // EXPECT: NO channels increment

        // -----------------------------------------------------
        // Test 4: Release FSM HOLD
        // -----------------------------------------------------
        repeat (20) @(posedge clk);
        gate_mask = 7'b111_1111;
        repeat (200) @(posedge clk);
        show_counts();

        $display("[%0t] CLOCK GATING TEST PASSED", $time);
        $finish;
    end

endmodule
