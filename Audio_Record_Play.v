module Audio_Record_Play (
    input wire clk,
    input wire daclrck,
    input wire rst_n,
    input wire record_key,
    input wire play_key,

    // RAM_RW
    output wire stop,
    output wire req_valid,
    output wire req_type,
    output wire req_target,
    input wire req_ready,
    input wire data_valid,
    input wire [15:0] data_out_l,
    input wire [15:0] data_out_r,
    input wire busy,

    // I2S_Tx_Slave
    output reg [15:0] tx_l_data,
    output reg [15:0] tx_r_data
);

    // 状态机
    localparam IDLE = 2'd0, RECORD = 2'd1, PLAY = 2'd2;
    reg [1:0] state = IDLE;
    reg req_valid_reg = 1'b0;
    reg req_type_reg = 1'b0;  // 0=读, 1=写
    reg stop_reg = 1'b1;

    // play_key 边沿检测
    reg play_key_prev = 1'b0;
    wire play_key_press = (~play_key) & play_key_prev; // 下降沿检测（假设低电平有效）

    // 状态机和控制逻辑
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            req_valid_reg <= 1'b0;
            req_type_reg <= 1'b0;
            stop_reg <= 1'b1;
            play_key_prev <= 1'b0;
        end else begin
            play_key_prev <= play_key;  // 更新 play_key 历史值
            case (state)
                IDLE: begin
                    req_valid_reg <= 1'b0;
                    stop_reg <= 1'b1;
                    if (!record_key) begin
                        // 按住 record_key 进入录音
                        state <= RECORD;
                        req_valid_reg <= 1'b1;
                        req_type_reg <= 1'b1;  // 写
                        stop_reg <= 1'b0;
                    end else if (play_key_press) begin
                        // 按一下 play_key 触发播放
                        state <= PLAY;
                        req_valid_reg <= 1'b1;  // 触发读请求
                        req_type_reg <= 1'b0;  // 读
                        stop_reg <= 1'b0;
                    end
                end
                RECORD: begin
                    if (record_key) begin
                        // 松开 record_key 停止录音
                        req_valid_reg <= 1'b0;
                        stop_reg <= 1'b1;
                        if (!busy) begin
                            state <= IDLE;
                        end
                    end else begin
                        req_valid_reg <= 1'b1;
                        stop_reg <= 1'b0;
                    end
                end
                PLAY: begin
                    if (play_key && !busy) begin
                        // 播放完成
                        req_valid_reg <= 1'b0;  // 读请求只需要一周期（触发）
                        state <= IDLE;
                        stop_reg <= 1'b1;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end

    // I2S 发送模块
    always @(posedge daclrck) begin
        if (!rst_n) begin
            tx_l_data <= 16'b0;
            tx_r_data <= 16'b0;
        end else if (data_valid) begin
            tx_l_data <= data_out_l;
            tx_r_data <= data_out_r;
        end
    end

    // 输出信号
    assign stop = stop_reg;
    assign req_valid = req_valid_reg;
    assign req_type = req_type_reg;
    assign req_target = 1'b0;  // 0=Rx

endmodule
