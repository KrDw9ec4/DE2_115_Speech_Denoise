module I2S_Rx_Slave (
    input wire bclk,
    input wire lrck,
    input wire sdata,
    input wire rst,

    output wire [15:0] l_data,
    output wire [15:0] r_data,
    output wire rx_done
);

reg [15:0] l_data_reg = 0;
reg [15:0] r_data_reg = 0;
reg [15:0] sreg = 0;

reg l_data_valid_reg = 0;
reg r_data_valid_reg = 0;
reg [3:0] bit_cnt = 0;

reg last_lrck = 0;
reg last_lrck2 = 0;

assign l_data = l_data_reg;
assign r_data = r_data_reg;
assign rx_done = l_data_valid_reg & r_data_valid_reg;

always @(posedge bclk) begin
    if (rst) begin
        l_data_reg <= 0;
        r_data_reg <= 0;
        l_data_valid_reg <= 0;
        r_data_valid_reg <= 0;
        sreg <= 0;
        bit_cnt <= 0;
        last_lrck <= 0;
        last_lrck2 <= 0;
    end

    last_lrck <= lrck;
    last_lrck2 <= last_lrck;

    // 新的一轮接收即将开始
    if (lrck != last_lrck) begin
        l_data_valid_reg <= 0;
        r_data_valid_reg <= 0;
    end

    // 开始接受数据
    if (last_lrck2 != last_lrck) begin
        bit_cnt <= 15;
        sreg <= {15'b0, sdata};
    end else begin
        if (bit_cnt > 0) begin
            bit_cnt <= bit_cnt - 1;
            if (bit_cnt > 1) begin
                sreg <= {sreg[14:0], sdata};
            end else begin
                if (!last_lrck) begin
                    l_data_reg <= {sreg[14:0], sdata};
                    l_data_valid_reg <= 1;
                end else begin
                    r_data_reg <= {sreg[14:0], sdata};
                    r_data_valid_reg <= 1;
                end
            end
        end
    end
end

endmodule