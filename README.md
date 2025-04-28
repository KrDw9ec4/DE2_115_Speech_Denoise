### 管脚分配 Pin Planner

| 信号名      | 信号类型 | 对应引脚 | 备注                             |
| ----------- | -------- | -------- | -------------------------------- |
| CLOCK_50M   | input    | PIN_Y2   | 系统时钟 50MHz                   |
| RST_N       | input    | PIN_M23  | KEY0，系统复位，低电平有效       |
| I2C_SCLK    | output   | PIN_B7   | I2C 总线时钟信号输出到 WM8731    |
| I2C_SDAT    | inout    | PIN_A8   | I2C 总线数据信号，双向           |
| AUD_BCLK    | input    | PIN_F2   | 数字音频位时钟输入到 FPGA        |
| AUD_ADCLRCK | input    | PIN_C2   | 数字音频左/右对齐时钟输入到 FPGA |
| AUD_DACLRCK | input    | PIN_E3   | 数字音频左/右对齐时钟输入到 FPGA |
| AUD_ADCDAT  | input    | PIN_D2   | ADC 数据输入到 FPGA              |
| AUD_XCK     | output   | PIN_E1   | WM8731 主时钟，频率 18.432MHz    |
| AUD_DACDAT  | output   | PIN_D1   | DAC 数据输出到 WM8731            |

