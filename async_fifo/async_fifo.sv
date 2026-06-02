`timescale 1ns/1ps

module async_fifo #(
    parameter   DATA_WIDTH=32,
    parameter   DEPTH=32

)(
    input                           wr_clk,
    input                           wr_rst_n,
    input[DATA_WIDTH-1:0]           wr_data,
    input                           wr_en,
    output                          full,

    input                           rd_clk,
    input                           rd_rst_n,
    output reg[DATA_WIDTH-1:0]      rd_data,
    input                           rd_en,
    output                          empty
);

localparam  ADDR_WIDTH=$clog2(DEPTH);
reg[DATA_WIDTH-1:0] fifo_ram [DEPTH-1:0];

wire[ADDR_WIDTH-1:0] wr_idx_true;
wire[ADDR_WIDTH-1:0] rd_idx_true;

reg[ADDR_WIDTH:0] wr_idx;
reg[ADDR_WIDTH:0] rd_idx;

wire[ADDR_WIDTH:0] wr_idx_gray;
wire[ADDR_WIDTH:0] rd_idx_gray;

assign wr_idx_true=wr_idx[ADDR_WIDTH-1:0];
assign rd_idx_true=rd_idx[ADDR_WIDTH-1:0];

assign wr_idx_gray=wr_idx^(wr_idx>>1);
assign rd_idx_gray=rd_idx^(rd_idx>>1);


wire wr_valid,rd_valid;
assign wr_valid=!full & wr_en;
assign rd_valid=!empty & rd_en;


always@(posedge wr_clk or negedge wr_rst_n)begin
    if(!wr_rst_n)begin
        wr_idx<=0;
    end
    else if(wr_valid)begin
        wr_idx<=wr_idx+1;
        fifo_ram[wr_idx_true]<=wr_data;
    end
end

always@(posedge rd_clk or negedge rd_rst_n)begin
    if(!rd_rst_n)begin
        rd_idx<=0;
        rd_data<=0;
    end
    else if(rd_valid)begin
        rd_idx<=rd_idx+1;
        rd_data<=fifo_ram[rd_idx_true];
    end
end

reg [ADDR_WIDTH:0] wr_gray_d1,wr_gray_d2;

reg [ADDR_WIDTH:0] rd_gray_d1,rd_gray_d2;

always@(posedge wr_clk or negedge wr_rst_n)begin
     if(!wr_rst_n)begin
        rd_gray_d1<=0;
        rd_gray_d2<=0;
     end
     else begin
        rd_gray_d1<=rd_idx_gray;
        rd_gray_d2<=rd_gray_d1;
     end
end

always@(posedge rd_clk or negedge rd_rst_n)begin
     if(!rd_rst_n)begin
        wr_gray_d1<=0;
        wr_gray_d2<=0;
     end
     else begin
        wr_gray_d1<=wr_idx_gray;
        wr_gray_d2<=wr_gray_d1;
     end
end

// judge full /empty

assign  empty=(wr_gray_d2==rd_idx_gray);
assign  full=(wr_idx_gray=={~rd_gray_d2[ADDR_WIDTH:ADDR_WIDTH-1],rd_gray_d2[ADDR_WIDTH-2:0]});

endmodule