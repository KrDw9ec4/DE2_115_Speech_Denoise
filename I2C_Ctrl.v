module I2C_Ctrl (
    input CLOCK, // I2C 控制器时钟输入
    output I2C_SCLK, // I2C 总线时钟信号输出
    inout I2C_SDAT, // I2C 总线数据信号
    input [23:0] I2C_DATA, // 要传输的数据 DATA:[SLAVE_ADDR, SUB_ADDR, DATA]
    input GO_TX, // 启动传输
    output reg END_TX, // 传输结束标志
    output ACK, // ACK 信号输出
    input RESET, // I2C 控制器复位信号
    // 以下信号为测试信号
    output reg [5:0] SD_COUNTER, // I2C 数据发送计数器
    output reg SDO // I2C 控制器发送到串行数据
);

reg SCLK;
reg [23:0] SD; // 发送数据

assign I2C_SCLK = SCLK | (((SD_COUNTER >= 4) & (SD_COUNTER <= 30)) ? ~CLOCK : 0);
assign I2C_SDAT = SDO ? 1'bz : 1'b0; // 如果输出数据为 1，I2C_SDAT 设为高阻态

reg ACK1, ACK2, ACK3;
assign ACK = ACK1 | ACK2 | ACK3; // ACK 信号

// I2C 计数器
always @(negedge RESET or posedge CLOCK) begin
    if (!RESET) SD_COUNTER = 6'b111111;
    else begin
        if (GO_TX == 0) SD_COUNTER = 0;
        else if (SD_COUNTER < 6'b111111) SD_COUNTER = SD_COUNTER + 1;
    end
end

always @(negedge RESET or posedge CLOCK) begin
    if (!RESET) begin
        SCLK = 1;
        SDO = 1;
        ACK1 = 0;
        ACK2 = 0;
        ACK3 = 0;
        END_TX = 1;
    end
    else case (SD_COUNTER)
        6'd0: begin ACK1 = 0; ACK2 = 0; ACK3 = 0; END_TX = 0; SDO = 1; SCLK = 1; end

        // I2C START
        6'd1: begin SD = I2C_DATA; SDO = 0; end
        6'd2: SCLK = 0;

        // 发送从设备地址 SLAVE_ADDR[6:0]
        6'd3: SDO = SD[23];
        6'd4: SDO = SD[22];
        6'd5: SDO = SD[21];
        6'd6: SDO = SD[20];
        6'd7: SDO = SD[19];
        6'd8: SDO = SD[18];
        6'd9: SDO = SD[17];
        // 读/写位
        6'd10: SDO = SD[16];
        6'd11: SDO = 1'b1; // ACK

        // 发送从设备寄存器地址 SUB_ADDR[7:0]
        6'd12: begin SDO = SD[15]; ACK1 = I2C_SDAT; end
        6'd13: SDO = SD[14];
        6'd14: SDO = SD[13];
        6'd15: SDO = SD[12];
        6'd16: SDO = SD[11];
        6'd17: SDO = SD[10];
        6'd18: SDO = SD[9];
        6'd19: SDO = SD[8];
        6'd20: SDO = 1'b1; // ACK

        // 发送数据 DATA[7:0]
        6'd21: begin SDO = SD[7]; ACK2 = I2C_SDAT; end
        6'd22: SDO = SD[6];
        6'd23: SDO = SD[5];
        6'd24: SDO = SD[4];
        6'd25: SDO = SD[3];
        6'd26: SDO = SD[2];
        6'd27: SDO = SD[1];
        6'd28: SDO = SD[0];
        6'd29: SDO = 1'b1; // ACK

        // I2C STOP
        6'd30: begin SDO = 1'b0; SCLK = 1'b0; ACK3 = I2C_SDAT; end
        6'd31: SCLK = 1'b1;
        6'd32: begin SDO = 1'b1; END_TX = 1; end
    endcase
end

endmodule