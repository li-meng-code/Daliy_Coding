`timescale 1ns/1ps

import dma_pkg::*;

module lite_config #(
    parameter ADDR_WIDTH = DMA_DEFAULT_ADDR_WIDTH,
    parameter DATA_WIDTH = DMA_DEFAULT_DATA_WIDTH
)(
    input                       clk,
    input                       rst_n,

    input  [ADDR_WIDTH-1:0]     s_axil_awaddr,
    input                       s_axil_awvalid,
    output                      s_axil_awready,

    input  [DATA_WIDTH-1:0]     s_axil_wdata,
    input  [DATA_WIDTH/8-1:0]   s_axil_wstrb,
    input                       s_axil_wvalid,
    output                      s_axil_wready,

    output reg [1:0]            s_axil_bresp,
    output                      s_axil_bvalid,
    input                       s_axil_bready,

    input  [ADDR_WIDTH-1:0]     s_axil_araddr,
    input                       s_axil_arvalid,
    output                      s_axil_arready,

    output reg [DATA_WIDTH-1:0] s_axil_rdata,
    output reg [1:0]            s_axil_rresp,
    output                      s_axil_rvalid,
    input                       s_axil_rready,

    input  [DATA_WIDTH-1:0]     status_i,

    output reg [ADDR_WIDTH-1:0] src_addr_o,
    output reg [ADDR_WIDTH-1:0] dst_addr_o,
    output reg [DATA_WIDTH-1:0] burst_len_o,
    output reg [DATA_WIDTH-1:0] bytes_len_o,

    output                      ctrl_start_o,
    output                      ctrl_irq_en_o,
    output                      ctrl_clear_done_o,
    output                      ctrl_clear_err_o
);

localparam [1:0] WR_IDLE    = 2'd0;
localparam [1:0] WR_COLLECT = 2'd1;
localparam [1:0] WR_RESP    = 2'd2;

localparam RD_IDLE = 1'b0;
localparam RD_RESP = 1'b1;

reg [DATA_WIDTH-1:0] control;

reg [1:0]              wr_state;
reg [ADDR_WIDTH-1:0]   awaddr_reg;
reg [DATA_WIDTH-1:0]   wdata_reg;
reg [DATA_WIDTH/8-1:0] wstrb_reg;
reg                    aw_seen;
reg                    w_seen;

reg                    rd_state;
reg [DATA_WIDTH-1:0]   rdata_next;
reg [1:0]              rresp_next;

wire aw_fire;
wire w_fire;
wire b_fire;
wire ar_fire;
wire r_fire;

wire [ADDR_WIDTH-1:0]   wr_addr_sel;
wire [DATA_WIDTH-1:0]   wr_data_sel;
wire [DATA_WIDTH/8-1:0] wstrb_sel;
wire [DATA_WIDTH-1:0]   control_next;

assign aw_fire = s_axil_awvalid && s_axil_awready;
assign w_fire  = s_axil_wvalid  && s_axil_wready;
assign b_fire  = s_axil_bvalid  && s_axil_bready;
assign ar_fire = s_axil_arvalid && s_axil_arready;
assign r_fire  = s_axil_rvalid  && s_axil_rready;

assign wr_addr_sel = aw_fire ? s_axil_awaddr : awaddr_reg;
assign wr_data_sel = w_fire  ? s_axil_wdata  : wdata_reg;
assign wstrb_sel   = w_fire  ? s_axil_wstrb  : wstrb_reg;

assign control_next = apply_wstrb(control, wr_data_sel, wstrb_sel);

assign ctrl_start_o      = control[DMA_CTRL_START];
assign ctrl_irq_en_o     = control[DMA_CTRL_IRQ_EN];
assign ctrl_clear_done_o = control[DMA_CTRL_CLEAR_DONE];
assign ctrl_clear_err_o  = control[DMA_CTRL_CLEAR_ERR];

function [DATA_WIDTH-1:0] apply_wstrb;
    input [DATA_WIDTH-1:0] old_data;
    input [DATA_WIDTH-1:0] wdata;
    input [DATA_WIDTH/8-1:0] wstrb;
    integer i;
    begin
        apply_wstrb = old_data;
        for(i = 0; i < DATA_WIDTH/8; i = i + 1)begin
            if(wstrb[i])
                apply_wstrb[i*8 +: 8] = wdata[i*8 +: 8];
        end
    end
endfunction

task reg_read;
    input  [ADDR_WIDTH-1:0] addr;
    output [DATA_WIDTH-1:0] data;
    output [1:0]            resp;
    begin
        data = {DATA_WIDTH{1'b0}};
        resp = DMA_RESP_OK;

        case(addr[7:0])
            DMA_REG_SRC_ADDR:  data = src_addr_o;
            DMA_REG_DST_ADDR:  data = dst_addr_o;
            DMA_REG_BURST_LEN: data = burst_len_o;
            DMA_REG_BYTES_LEN: data = bytes_len_o;
            DMA_REG_CONTROL:   data = control;
            DMA_REG_STATUS:    data = status_i;
            default: begin
                data = {DATA_WIDTH{1'b0}};
                resp = DMA_RESP_SLVERR;
            end
        endcase
    end
endtask

task reg_write;
    input  [ADDR_WIDTH-1:0]   addr;
    input  [DATA_WIDTH-1:0]   wdata;
    input  [DATA_WIDTH/8-1:0] wstrb;
    output [1:0]              resp;
    begin
        resp = DMA_RESP_OK;

        case(addr[7:0])
            DMA_REG_SRC_ADDR: begin
                src_addr_o <= apply_wstrb(src_addr_o, wdata, wstrb);
            end
            DMA_REG_DST_ADDR: begin
                dst_addr_o <= apply_wstrb(dst_addr_o, wdata, wstrb);
            end
            DMA_REG_BURST_LEN: begin
                burst_len_o <= apply_wstrb(burst_len_o, wdata, wstrb);
            end
            DMA_REG_BYTES_LEN: begin
                bytes_len_o <= apply_wstrb(bytes_len_o, wdata, wstrb);
            end
            DMA_REG_CONTROL: begin
                control[DMA_CTRL_START]      <= control_next[DMA_CTRL_START];
                control[DMA_CTRL_IRQ_EN]     <= control_next[DMA_CTRL_IRQ_EN];
                control[DMA_CTRL_CLEAR_DONE] <= control_next[DMA_CTRL_CLEAR_DONE];
                control[DMA_CTRL_CLEAR_ERR]  <= control_next[DMA_CTRL_CLEAR_ERR];
            end
            default: begin
                resp = DMA_RESP_SLVERR;
            end
        endcase
    end
endtask

always @(*) begin
    reg_read(s_axil_araddr, rdata_next, rresp_next);
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        wr_state     <= WR_IDLE;
        awaddr_reg   <= {ADDR_WIDTH{1'b0}};
        wdata_reg    <= {DATA_WIDTH{1'b0}};
        wstrb_reg    <= {DATA_WIDTH/8{1'b0}};
        aw_seen      <= 1'b0;
        w_seen       <= 1'b0;
        src_addr_o   <= {ADDR_WIDTH{1'b0}};
        dst_addr_o   <= {ADDR_WIDTH{1'b0}};
        burst_len_o  <= {DATA_WIDTH{1'b0}};
        bytes_len_o  <= {DATA_WIDTH{1'b0}};
        control      <= {DATA_WIDTH{1'b0}};
        s_axil_bresp <= DMA_RESP_OK;
    end
    else begin
        control[DMA_CTRL_START]      <= 1'b0;
        control[DMA_CTRL_CLEAR_DONE] <= 1'b0;
        control[DMA_CTRL_CLEAR_ERR]  <= 1'b0;

        case(wr_state)
            WR_IDLE,
            WR_COLLECT: begin
                if(aw_fire)begin
                    awaddr_reg <= s_axil_awaddr;
                    aw_seen    <= 1'b1;
                end

                if(w_fire)begin
                    wdata_reg <= s_axil_wdata;
                    wstrb_reg <= s_axil_wstrb;
                    w_seen    <= 1'b1;
                end

                if((aw_fire || aw_seen) && (w_fire || w_seen))begin
                    reg_write(wr_addr_sel, wr_data_sel, wstrb_sel, s_axil_bresp);
                    aw_seen  <= 1'b0;
                    w_seen   <= 1'b0;
                    wr_state <= WR_RESP;
                end
                else if(aw_fire || w_fire)begin
                    wr_state <= WR_COLLECT;
                end
            end

            WR_RESP: begin
                if(b_fire)
                    wr_state <= WR_IDLE;
            end

            default: begin
                wr_state <= WR_IDLE;
            end
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        rd_state     <= RD_IDLE;
        s_axil_rdata <= {DATA_WIDTH{1'b0}};
        s_axil_rresp <= DMA_RESP_OK;
    end
    else begin
        case(rd_state)
            RD_IDLE: begin
                if(ar_fire)begin
                    s_axil_rdata <= rdata_next;
                    s_axil_rresp <= rresp_next;
                    rd_state     <= RD_RESP;
                end
            end

            RD_RESP: begin
                if(r_fire)
                    rd_state <= RD_IDLE;
            end

            default: begin
                rd_state <= RD_IDLE;
            end
        endcase
    end
end

assign s_axil_awready = (wr_state != WR_RESP) && (!aw_seen);
assign s_axil_wready  = (wr_state != WR_RESP) && (!w_seen);
assign s_axil_bvalid  = (wr_state == WR_RESP);

assign s_axil_arready = (rd_state == RD_IDLE);
assign s_axil_rvalid  = (rd_state == RD_RESP);

endmodule