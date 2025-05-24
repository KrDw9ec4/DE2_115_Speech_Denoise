module RAM_RW (
    input  wire        clk,         // 时钟信号
    input  wire        stop,        // 暂停地址递增
    input  wire        req_valid,   // 请求有效
    input  wire        req_type,    // 0=读, 1=写
    input  wire        req_target,  // 0=Rx, 1=Tx
    input  wire [15:0] data_in_l,   // 左声道写数据
    input  wire [15:0] data_in_r,   // 右声道写数据
    output wire        req_ready,   // 模块准备好接受请求
    output wire        data_valid,  // 读数据有效
    output wire [15:0] data_out_l,  // 左声道读数据
    output wire [15:0] data_out_r,  // 右声道读数据
    output wire        busy         //  DAY忙碌
);

    // 内部寄存器
    reg [15:0] ram_addr = 16'b0;  // 当前RAM地址
    reg [15:0] max_addr_rx_l = 16'b0;  // Rx左声道最大地址
    reg [15:0] max_addr_rx_r = 16'b0;  // Rx右声道最大地址
    reg [15:0] max_addr_tx_l = 16'b0;  // Tx左声道最大地址
    reg [15:0] max_addr_tx_r = 16'b0;  // Tx右声道最大地址
    reg [15:0] read_max_addr_l = 16'b0;  // 读操作的最大地址（左声道）
    reg [15:0] read_max_addr_r = 16'b0;  // 读操作的最大地址（右声道）
    reg wren_rx_l, wren_rx_r, wren_tx_l, wren_tx_r;  // 写使能信号
    reg [15:0] data_rx_l, data_rx_r, data_tx_l, data_tx_r;  // 写数据
    reg data_valid_reg = 1'b0;  // 数据有效寄存器
    reg busy_reg = 1'b0;  // 忙碌状态寄存器

    // 状态机定义
    localparam IDLE = 3'd0,  // 空闲状态
    READ_MAX = 3'd1,  // 读取16'hFFFF
    READ_DATA = 3'd2,  // 读取数据
    WRITE_DATA = 3'd3,  // 写入数据
    WRITE_MAX = 3'd4;  // 写入max_addr到16'hFFFF
    reg [2:0] state = IDLE;  // 状态机状态

    // RAM输出
    wire [15:0] q_rx_l, q_rx_r, q_tx_l, q_tx_r;

    // 状态机
    // 查询 Intel RAM IP 核的手册，发现 RAM 的读写操作都在上升沿触发
    // 所以更新地址 ram_addr 和数据的操作在下降沿进行
    always @(negedge clk) begin
        case (state)
            IDLE: begin
                wren_rx_l <= 1'b0;
                wren_rx_r <= 1'b0;
                wren_tx_l <= 1'b0;
                wren_tx_r <= 1'b0;
                data_valid_reg <= 1'b0;
                if (req_valid && req_ready) begin
                    busy_reg <= 1'b1;
                    if (req_type == 1'b0) begin
                        // 读操作：先读取16'hFFFF
                        state <= READ_MAX;
                        ram_addr <= 16'hFFFF;
                    end else begin
                        // 写操作：重置地址和max_addr
                        state <= WRITE_DATA;
                        ram_addr <= 16'b0;
                        if (req_target == 1'b0) begin
                            max_addr_rx_l <= 16'b0;
                            max_addr_rx_r <= 16'b0;
                        end else begin
                            max_addr_tx_l <= 16'b0;
                            max_addr_tx_r <= 16'b0;
                        end
                    end
                end
            end
            READ_MAX: begin
                // 存储16'hFFFF的读取值
                if (req_target == 1'b0) begin
                    read_max_addr_l <= q_rx_l;
                    read_max_addr_r <= q_rx_r;
                end else begin
                    read_max_addr_l <= q_tx_l;
                    read_max_addr_r <= q_tx_r;
                end
                ram_addr <= 16'b0;
                state <= READ_DATA;
            end
            READ_DATA: begin
                if (!stop && (
                    (req_target == 1'b0 && ram_addr < read_max_addr_l) ||
                    (req_target == 1'b1 && ram_addr < read_max_addr_l)
                )) begin
                    ram_addr <= ram_addr + 1;
                    data_valid_reg <= 1'b1;
                end else begin
                    data_valid_reg <= 1'b0;
                    busy_reg <= 1'b0;
                    state <= IDLE;
                end
            end
            WRITE_DATA: begin
                if (req_valid && !stop) begin
                    // 写入数据并更新max_addr
                    if (req_target == 1'b0) begin
                        wren_rx_l <= 1'b1;
                        wren_rx_r <= 1'b1;
                        data_rx_l <= data_in_l;
                        data_rx_r <= data_in_r;
                        if (ram_addr >= max_addr_rx_l) begin
                            max_addr_rx_l <= ram_addr + 1;
                            max_addr_rx_r <= ram_addr + 1;
                        end
                    end else begin
                        wren_tx_l <= 1'b1;
                        wren_tx_r <= 1'b1;
                        data_tx_l <= data_in_l;
                        data_tx_r <= data_in_r;
                        if (ram_addr >= max_addr_tx_l) begin
                            max_addr_tx_l <= ram_addr + 1;
                            max_addr_tx_r <= ram_addr + 1;
                        end
                    end
                    ram_addr <= (ram_addr == 16'hFFFE) ? ram_addr : ram_addr + 1;
                end else begin
                    // 写结束，准备写入max_addr
                    wren_rx_l <= 1'b0;
                    wren_rx_r <= 1'b0;
                    wren_tx_l <= 1'b0;
                    wren_tx_r <= 1'b0;
                    state <= WRITE_MAX;
                    ram_addr <= 16'hFFFF;
                end
            end
            WRITE_MAX: begin
                // 写入max_addr到16'hFFFF
                if (req_target == 1'b0) begin
                    wren_rx_l <= 1'b1;
                    wren_rx_r <= 1'b1;
                    data_rx_l <= max_addr_rx_l;
                    data_rx_r <= max_addr_rx_r;
                end else begin
                    wren_tx_l <= 1'b1;
                    wren_tx_r <= 1'b1;
                    data_tx_l <= max_addr_tx_l;
                    data_tx_r <= max_addr_tx_r;
                end
                state <= IDLE;
                busy_reg <= 1'b0;
            end
        endcase
    end

    // RAM实例
    RAM RAM_Rx_L (
        .address(ram_addr),
        .clock(clk),
        .data(data_rx_l),
        .wren(wren_rx_l),
        .q(q_rx_l)
    );

    RAM RAM_Rx_R (
        .address(ram_addr),
        .clock(clk),
        .data(data_rx_r),
        .wren(wren_rx_r),
        .q(q_rx_r)
    );

    RAM RAM_Tx_L (
        .address(ram_addr),
        .clock(clk),
        .data(data_tx_l),
        .wren(wren_tx_l),
        .q(q_tx_l)
    );

    RAM RAM_Tx_R (
        .address(ram_addr),
        .clock(clk),
        .data(data_tx_r),
        .wren(wren_tx_r),
        .q(q_tx_r)
    );

    // 输出分配
    assign req_ready = (state == IDLE);
    assign data_valid = data_valid_reg;
    assign busy = busy_reg;
    assign data_out_l = (req_target == 1'b0) ? q_rx_l : q_tx_l;
    assign data_out_r = (req_target == 1'b0) ? q_rx_r : q_tx_r;

endmodule
