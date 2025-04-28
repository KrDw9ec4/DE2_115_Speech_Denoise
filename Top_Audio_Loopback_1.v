module Top_Audio_Loopback_1 (
    input wire CLOCK_50M, // 系统时钟 50MHz
    input wire RST_N, // 系统复位，低电平有效
    // I2C 总线协议
    output wire I2C_SCLK, // I2C 总线时钟信号输出到 WM8731
    inout wire I2C_SDAT, // I2C 总线数据信号，双向
    // WM8731 工作在主模式，由 WM8731 控制数字音频数据接口的时序，输入到 FPGA。
    input wire AUD_BCLK, // 数字音频位时钟输入到 FPGA
    input wire AUD_ADCLRCK, // 数字音频左/右对齐时钟输入到 FPGA
    input wire AUD_DACLRCK, // 数字音频左/右对齐时钟输入到 FPGA
    input wire AUD_ADCDAT, // ADC 数据输入到 FPGA
    // WM8731 工作在主模式，但其主时钟和 DAC 数据由 FPGA 产生。
    output wire AUD_XCK, // WM8731 主时钟，频率 18.432MHz
    output wire AUD_DACDAT // DAC 数据输出到 WM8731
);

// WM8731 主时钟产生
Audio_PLL Audio_PLL_inst(
    .areset(~RST_N), // 异步复位，取反连接
    .inclk0(CLOCK_50M), // 输入系统时钟（50MHz）
    .c0(AUD_XCK), // 输出时钟（18.432MHz）
    // .locked() // 输出稳定时钟标志信号
);

// WM8731 初始化配置
WM8731_Init WM8731_Init_inst(
    .iCLK(CLOCK_50M), // 输入系统时钟（50MHz）
    .iRST_N(RST_N), // 输入复位信号
    .I2C_SCLK(I2C_SCLK), // I2C 总线时钟信号
    .I2C_SDAT(I2C_SDAT) // I2C 总线数据信号
);

// QUESTION): 怎么实现直接将 ADC 数据输出到 DAC 数据输入？
assign AUD_DACDAT = AUD_ADCDAT;

endmodule