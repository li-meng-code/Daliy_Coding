`timescale 1ns/1ps

module fifo #(
    parameter  DATA_WIDTH=32,
    parameter  DEPTH=32
)(
    input                           clk,
    input                           rst_n,
    input                           wr_en,
    input[DATA_WIDTH-1:0]           data_in,
    output                          full,

    output reg[DATA_WIDTH-1:0]          data_out,
    input                               rd_en,
    output                              empty
);

reg[DATA_WIDTH-1:0]  fifo_ram [DEPTH-1:0];

localparam   ADDR_WIDTH=$clog2(DEPTH);
reg[ADDR_WIDTH-1:0] wr_idx;
reg[ADDR_WIDTH-1:0] rd_idx;
reg[ADDR_WIDTH:0]   wr_idx_ext;
reg[ADDR_WIDTH:0]   rd_idx_ext;

assign wr_idx=wr_idx_ext[ADDR_WIDTH-1:0];
assign rd_idx=rd_idx_ext[ADDR_WIDTH-1:0];

wire wr_valid,rd_valid;

assign wr_valid=wr_en& !full;
assign rd_valid=rd_en& !empty;

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        wr_idx_ext<=0;
    end
    else if(wr_valid)begin
        fifo_ram[wr_idx]<=data_in;
        wr_idx_ext<=wr_idx_ext+1;
    end
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        rd_idx_ext<=0;
    end
    else if (rd_valid)begin
        data_out<=fifo_ram[rd_idx];
        rd_idx_ext<=rd_idx_ext+1;
    end
end


assign full=(wr_idx_ext[ADDR_WIDTH]!=rd_idx_ext[ADDR_WIDTH])&&(rd_idx==wr_idx);
assign empty=(rd_idx_ext==wr_idx_ext);



endmodule