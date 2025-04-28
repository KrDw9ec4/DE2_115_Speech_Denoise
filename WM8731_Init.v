module WM8731_Init (
    input iCLK, // 时钟输入
    input iRST_N, // 复位信号
    output I2C_SCLK, // I2C 总线时钟信号输出
    inout I2C_SDAT // I2C 总线数据信号
);
// 内部寄存器及连线
reg [15:0] mI2C_CLK_DIV;
reg [23:0] mI2C_DATA;
reg mI2C_CTRL_CLK;
reg mI2C_GO;
wire mI2C_END;
wire mI2C_ACK;
reg [15:0] LUT_DATA;
reg [5:0] LUT_INDEX;
reg [3:0] mSetup_ST;

// 时钟参数
parameter CLK_Freq = 50000000; // 输入的系统时钟 50MHz
parameter I2C_Freq = 20000; // I2C 总线时钟 20KHz

// 存储音频编/解码器配置数据的查找表容量
parameter LUT_SIZE = 12;

// 音频编/解码器配置数据索引
parameter DUMMY_DATA_start = 0;
parameter SET_LIN_L = 1;
parameter SET_LIN_R = 2;
parameter SET_HEAD_L = 3;
parameter SET_HEAD_R = 4;
parameter A_PATH_CTRL = 5;
parameter D_PATH_CTRL = 6;
parameter POWER_ON = 7;
parameter SET_FORMAT = 8;
parameter SAMPLE_CTRL = 9;
parameter SET_ACTIVE = 10;
parameter DUMMY_DATA_end = 11;

// 50MHz 时钟分频得到 20kHz 的 I2C 控制时钟
always @(posedge iCLK or negedge iRST_N) begin
    begin
        if (!iRST_N) begin
            mI2C_CTRL_CLK <= 0;
            mI2C_CLK_DIV <= 0;
        end
        else begin
            if (mI2C_CLK_DIV < (CLK_Freq / I2C_Freq))
            mI2C_CLK_DIV <= mI2C_CLK_DIV + 1'b1;
            else begin
                mI2C_CLK_DIV <= 0;
                mI2C_CTRL_CLK <= ~mI2C_CTRL_CLK;
            end
        end
    end
end

// 例化 I2C 控制器
I2C_Ctrl u0 (
    .CLOCK(mI2C_CTRL_CLK), // I2C 控制器工作时钟
    .I2C_SCLK(I2C_SCLK), // I2C 总线时钟信号
    .I2C_SDAT(I2C_SDAT), // I2C 总线数据信号
    .I2C_DATA(mI2C_DATA), // DATA:[SLAVE_ADDR, SUB_ADDR, DATA]
    .GO_TX(mI2C_GO), // 启动传输
    .END_TX(mI2C_END), // 传输结束标志
    .ACK(mI2C_ACK), // ACK 信号输出
    .RESET(iRST_N) // I2C 控制器复位信号
);

// 配置过程控制
always @(posedge mI2C_CTRL_CLK or negedge iRST_N)
    begin
        if (!iRST_N) begin
            LUT_INDEX <= 0;
            mSetup_ST <= 0;
            mI2C_GO <= 0;
        end 
        else begin
            if (LUT_INDEX < LUT_SIZE) begin
                case (mSetup_ST)
                    0: begin // 第一步：准备数据，启动传输
                        /* 
                        * 2 线模式下，通过引脚 CSB 选择 WM8731 在 I2C 总线上的地址。
                        * 若 CSB 引脚接地，则读地址为 0x34，写地址为 0x35。
                        * QUESTION): 为什么这里的地址是 0x34 而不是 0x35？
                        * INFO): 在友晶科技给出的原理图中，给出“I2C ADDRESS = 0x34 (write only)”。
                        */
                        mI2C_DATA <= {8'h34,LUT_DATA};
                        mI2C_GO <= 1;
                        mSetup_ST <= 1;
                    end
                    1: begin
                        if (mI2C_END) begin // 第二步：检验传输是否正常结束
                            if (!mI2C_ACK) mSetup_ST <= 2;
                            else mSetup_ST <= 0;
                            mI2C_GO <= 0;
                        end
                    end
                    2: begin // 第三步：传输结束，改变 LUT_INDEX 的值，准备传输下一个数据
                        LUT_INDEX <= LUT_INDEX + 1;
                        mSetup_ST <= 0;
                    end 
                endcase
            end
        end
    end

// 配置数据查找表
always begin
    case (LUT_INDEX)
        // 线路输入静音
        SET_LIN_L: LUT_DATA <= 16'h0097;
        SET_LIN_R: LUT_DATA <= 16'h0297;
        // MIC_IN 取消静音
        SET_HEAD_L: LUT_DATA <= 16'h047B;
        SET_HEAD_R: LUT_DATA <= 16'h067B;
        /* 
        * 模拟音频路径控制
        * 寄存器地址 00001000
        * 寄存器数据 00010101
        */
        A_PATH_CTRL: LUT_DATA <= 16'h0815;
        // 数字音频路径控制
        D_PATH_CTRL: LUT_DATA <= 16'h0A00;
        // 掉电控制
        POWER_ON: LUT_DATA <= 16'h0C00;
        /* 
        * 数字音频格式控制
        * 寄存器地址 00001110
        * 寄存器数据 01000010
        */
        SET_FORMAT: LUT_DATA <= 16'h0E42;
        /* 采样控制
        * 寄存器地址 00010000
        * 寄存器数据 00001110
        */
        SAMPLE_CTRL: LUT_DATA <= 16'h100E;
        // 数字音频接口激活
        SET_ACTIVE: LUT_DATA <= 16'h1201;
        default: LUT_DATA <= 16'h0000;
    endcase
end

endmodule