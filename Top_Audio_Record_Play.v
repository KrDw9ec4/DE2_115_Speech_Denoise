module Top_Audio_Record_Play (
    input  wire       CLOCK_50M,    // 系统时钟 50MHz
    input  wire       RST_N,        // 系统复位，低电平有效
    input  wire       KEY1,         // 录音按键，按住录音，松开停止（带消抖）
    input  wire       KEY2,         // 播放按键，按一下播放（带消抖）
    output wire [2:0] LEDG,
    // I2C 总线协议
    output wire       I2C_SCLK,     // I2C 总线时钟信号输出到 WM8731
    inout  wire       I2C_SDAT,     // I2C 总线数据信号，双向
    // WM8731 工作在主模式
    input  wire       AUD_BCLK,     // 数字音频位时钟输入到 FPGA
    input  wire       AUD_ADCLRCK,  // 数字音频左/右对齐时钟（ADC）
    input  wire       AUD_DACLRCK,  // 数字音频左/右对齐时钟（DAC）
    input  wire       AUD_ADCDAT,   // ADC 数据输入到 FPGA
    output wire       AUD_XCK,      // WM8731 主时钟，18.432MHz
    output wire       AUD_DACDAT    // DAC 数据输出到 WM8731
);

    wire ram_stop, ram_req_valid, ram_req_type, ram_req_target;
    wire ram_req_ready, ram_data_valid, ram_busy;
    wire [15:0] ram_data_out_l, ram_data_out_r;
    wire [15:0] rx_l_data, rx_r_data;
    wire [15:0] tx_l_data, tx_r_data;

    assign LEDG[0] = RST_N;
    assign LEDG[1] = ~KEY1;
    assign LEDG[2] = ~KEY2;

    // WM8731 主时钟产生
    Audio_PLL Audio_PLL_inst (
        .areset(~RST_N),
        .inclk0(CLOCK_50M),
        .c0(AUD_XCK)
    );

    // WM8731 初始化配置
    WM8731_Init WM8731_Init_inst (
        .iCLK(CLOCK_50M),
        .iRST_N(RST_N),
        .I2C_SCLK(I2C_SCLK),
        .I2C_SDAT(I2C_SDAT)
    );

    // I2S 接收模块
    I2S_Rx_Slave I2S_Rx_inst (
        .bclk(AUD_BCLK),
        .lrck(AUD_ADCLRCK),
        .sdata(AUD_ADCDAT),
        .rst(~RST_N),
        .l_data(rx_l_data),
        .r_data(rx_r_data),
        .rx_done()
    );

    // Audio_Record_Play
    Audio_Record_Play Audio_Record_Play_inst (
        .clk(CLOCK_50M),
        .daclrck(AUD_DACLRCK),
        .rst_n(RST_N),
        .record_key(KEY1),
        .play_key(KEY2),
        // RAM_RW
        .stop(ram_stop),
        .req_valid(ram_req_valid),
        .req_type(ram_req_type),
        .req_target(ram_req_target),  // 仅使用 Rx RAM
        .req_ready(ram_req_ready),
        .data_valid(ram_data_valid),
        .data_out_l(ram_data_out_l),
        .data_out_r(ram_data_out_r),
        .busy(ram_busy),
        // I2S_Tx_Slave
        .tx_l_data(tx_l_data),
        .tx_r_data(tx_r_data)
    );

    // RAM_RW 模块
    RAM_RW RAM_RW_inst (
        .clk(AUD_ADCLRCK),
        .stop(ram_stop),
        .req_valid(ram_req_valid),
        .req_type(ram_req_type),
        .req_target(ram_req_target),  // 仅使用 Rx RAM
        .data_in_l(rx_l_data),
        .data_in_r(rx_r_data),
        .req_ready(ram_req_ready),
        .data_valid(ram_data_valid),
        .data_out_l(ram_data_out_l),
        .data_out_r(ram_data_out_r),
        .busy(ram_busy)
    );

    I2S_Tx_Slave I2S_Tx_inst (
        .bclk(AUD_BCLK),
        .lrck(AUD_DACLRCK),
        .sdata(AUD_DACDAT),
        .rst(~RST_N),
        .l_data(tx_l_data),
        .r_data(tx_r_data)
    );

endmodule
