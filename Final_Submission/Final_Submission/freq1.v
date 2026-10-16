`timescale 1ns/1ps

module Freq (
    input  wire        clk,        // system clock
    input  wire        rst,        // active-high reset
    input  wire [31:0] divisor,    // dynamic divisor
    output reg         clk_en      // clock enable pulse
);

    reg [31:0] count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count  <= 32'd0;
            clk_en <= 1'b0;
        end else if (divisor <= 1) begin
            // Avoid divide-by-zero or invalid values
            clk_en <= 1'b1;
        end else if (count == (divisor - 1)) begin
            count  <= 32'd0;
            clk_en <= 1'b1;   // one-cycle enable pulse
        end else begin
            count  <= count + 1'b1;
            clk_en <= 1'b0;
        end
    end

endmodule
