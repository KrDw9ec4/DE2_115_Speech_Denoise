module I2S_Tx_Slave (
    input wire bclk,
    input wire lrck,
    output wire sdata,
    input wire rst,

    input wire [15:0] l_data,
    input wire [15:0] r_data
);

reg [15:0] sreg = 0;

reg [3:0] bit_cnt = 0;
reg sdata_reg = 0;

reg last_lrck = 0;
reg last_lrck2 = 0;

assign sdata = sdata_reg;

always @(posedge bclk) begin
    if (rst) begin
        last_lrck <= 0;
    end

    last_lrck <= lrck;
    last_lrck2 <= last_lrck;
end

always @(negedge bclk) begin
    if (rst) begin
        bit_cnt <= 0;
        sreg <= 0;
        sdata_reg <= 0;
    end

    if (last_lrck2 != last_lrck) begin
        bit_cnt <= 15;
        if (!lrck) begin
            {sdata_reg, sreg} <= {l_data[15:0], 1'b0};
        end else begin
            {sdata_reg, sreg} <= {r_data[15:0], 1'b0};
        end
    end else begin
        if (bit_cnt > 0) begin
            bit_cnt <= bit_cnt - 1;
            {sdata_reg, sreg} <= {sreg[15:0], 1'b0};
        end
    end
end

endmodule