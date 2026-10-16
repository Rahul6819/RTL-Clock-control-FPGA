`timescale 1ns / 1ps

//==============================================================
// FSM Controller for Safe Clock-Frequency Switching
// Enhanced with Watchdog Timeout and Error State
//==============================================================
module fsm_clk_ctrl #(
    parameter TIMEOUT_LIMIT = 16'hFFFF  // Configurable timeout threshold
)(
    input  wire clk,              // system clock (sys_clk)
    input  wire rstn,             // active-low reset
    input  wire freq_change_req,  // request to change clock frequency
    input  wire all_fifos_empty,  // from top FIFO block
    output reg  hold_fifos,       // high => disable FIFO R/W
    output reg  freq_update_en,   // enables Freq modules to update
    output reg  done,             // indicates safe-to-resume state
    output reg  fsm_error         // NEW: High if watchdog times out
);

    // State encoding
    localparam IDLE            = 3'd0;
    localparam FREQ_CHANGE_REQ  = 3'd1;
    localparam WAIT_FIFO_EMPTY  = 3'd2;
    localparam UPDATE_FREQ      = 3'd3;
    localparam WAIT_STABLE      = 3'd4;
    localparam RESUME           = 3'd5;
    localparam ERROR            = 3'd6; // NEW: Explicit Error State

    reg [2:0] state, next_state;
    reg [7:0] wait_cnt;
    reg [15:0] timeout_cnt; // NEW: Watchdog counter for stall detection

    // Sequential state register
    always @(posedge clk or negedge rstn) begin
        if (!rstn)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Counter for stabilization wait
    always @(posedge clk or negedge rstn) begin
        if (!rstn)
            wait_cnt <= 8'd0;
        else if (state == WAIT_STABLE)
            wait_cnt <= wait_cnt + 1'b1;
        else
            wait_cnt <= 8'd0;
    end

    // NEW: Counter for Watchdog Timeout
    always @(posedge clk or negedge rstn) begin
        if (!rstn)
            timeout_cnt <= 16'd0;
        else if (state == WAIT_FIFO_EMPTY)
            timeout_cnt <= timeout_cnt + 1'b1;
        else
            timeout_cnt <= 16'd0;
    end

    // Combinational next-state + outputs
    always @(*) begin
        // default outputs
        next_state     = state;
        hold_fifos     = 1'b0;
        freq_update_en = 1'b0;
        done           = 1'b0;
        fsm_error      = 1'b0; // Default: No error

        case (state)
            IDLE: begin
                if (freq_change_req)
                    next_state = FREQ_CHANGE_REQ;
            end

            FREQ_CHANGE_REQ: begin
                hold_fifos = 1'b1;
                next_state = WAIT_FIFO_EMPTY;
            end

            WAIT_FIFO_EMPTY: begin
                hold_fifos = 1'b1;
                if (all_fifos_empty)
                    next_state = UPDATE_FREQ;
                // Transition to ERROR if FIFOs don't empty in time
                else if (timeout_cnt >= TIMEOUT_LIMIT)
                    next_state = ERROR; 
            end

            UPDATE_FREQ: begin
                hold_fifos     = 1'b1;
                freq_update_en = 1'b1;
                next_state     = WAIT_STABLE;
            end

            WAIT_STABLE: begin
                hold_fifos     = 1'b1;
                freq_update_en = 1'b1;
                if (wait_cnt == 8'd100)
                    next_state = RESUME;
            end

            RESUME: begin
                done       = 1'b1;
                next_state = IDLE;
            end

            // NEW: Stay in ERROR state until a hardware reset (rstn)
            ERROR: begin
                fsm_error  = 1'b1;
                hold_fifos = 1'b1; // Lock FIFOs for safety
                next_state = ERROR; 
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule