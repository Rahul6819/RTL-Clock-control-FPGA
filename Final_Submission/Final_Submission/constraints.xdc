############################################################
# Day 6 - Timing Constraints
# Clock Control + Multi-Clock FIFO System
############################################################

# ----------------------------------------------------------
# 1. Primary AXI Clock (100 MHz)
# ----------------------------------------------------------
create_clock -name sys_clk -period 10.000 \
    [get_ports S_AXI_ACLK]

# ----------------------------------------------------------
# 2. Generated Clocks (Clock Enable Generators)
# ----------------------------------------------------------
create_generated_clock -name gen_clk_0 \
    -source [get_ports S_AXI_ACLK] \
    [get_pins integrated_core_inst/GEN_CLK_EN[0].freq_inst/clk_div_reg/Q]

create_generated_clock -name gen_clk_1 \
    -source [get_ports S_AXI_ACLK] \
    [get_pins integrated_core_inst/GEN_CLK_EN[1].freq_inst/clk_div_reg/Q]

create_generated_clock -name gen_clk_2 \
    -source [get_ports S_AXI_ACLK] \
    [get_pins integrated_core_inst/GEN_CLK_EN[2].freq_inst/clk_div_reg/Q]

create_generated_clock -name gen_clk_3 \
    -source [get_ports S_AXI_ACLK] \
    [get_pins integrated_core_inst/GEN_CLK_EN[3].freq_inst/clk_div_reg/Q]

create_generated_clock -name gen_clk_4 \
    -source [get_ports S_AXI_ACLK] \
    [get_pins integrated_core_inst/GEN_CLK_EN[4].freq_inst/clk_div_reg/Q]

create_generated_clock -name gen_clk_5 \
    -source [get_ports S_AXI_ACLK] \
    [get_pins integrated_core_inst/GEN_CLK_EN[5].freq_inst/clk_div_reg/Q]

create_generated_clock -name gen_clk_6 \
    -source [get_ports S_AXI_ACLK] \
    [get_pins integrated_core_inst/GEN_CLK_EN[6].freq_inst/clk_div_reg/Q]

# ----------------------------------------------------------
# 3. Asynchronous Clock Groups
# ----------------------------------------------------------
set_clock_groups -asynchronous \
    -group [get_clocks sys_clk] \
    -group [get_clocks gen_clk_*]

# ----------------------------------------------------------
# 4. Ignore Reset Timing
# ----------------------------------------------------------
set_false_path -from [get_ports S_AXI_ARESETN]
