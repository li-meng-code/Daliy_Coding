`timescale 1ns/1ps

import dma_pkg::*;

module dma_axi #(
    parameter ADDR_WIDTH = DMA_DEFAULT_ADDR_WIDTH,
    parameter DATA_WIDTH = DMA_DEFAULT_DATA_WIDTH,
    parameter ID_WIDTH   = DMA_DEFAULT_ID_WIDTH
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

    output [1:0]                s_axil_bresp,
    output                      s_axil_bvalid,
    input                       s_axil_bready,

    input  [ADDR_WIDTH-1:0]     s_axil_araddr,
    input                       s_axil_arvalid,
    output                      s_axil_arready,

    output [DATA_WIDTH-1:0]     s_axil_rdata,
    output [1:0]                s_axil_rresp,
    output                      s_axil_rvalid,
    input                       s_axil_rready,

    output [ID_WIDTH-1:0]       m_axi_arid,
    output [ADDR_WIDTH-1:0]     m_axi_araddr,
    output [7:0]                m_axi_arlen,
    output [2:0]                m_axi_arsize,
    output [1:0]                m_axi_arburst,
    output                      m_axi_arvalid,
    input                       m_axi_arready,

    input  [ID_WIDTH-1:0]       m_axi_rid,
    input  [DATA_WIDTH-1:0]     m_axi_rdata,
    input  [1:0]                m_axi_rresp,
    input                       m_axi_rlast,
    input                       m_axi_rvalid,
    output                      m_axi_rready,

    output [ID_WIDTH-1:0]       m_axi_awid,
    output [ADDR_WIDTH-1:0]     m_axi_awaddr,
    output [7:0]                m_axi_awlen,
    output [2:0]                m_axi_awsize,
    output [1:0]                m_axi_awburst,
    output                      m_axi_awvalid,
    input                       m_axi_awready,

    output [DATA_WIDTH-1:0]     m_axi_wdata,
    output [DATA_WIDTH/8-1:0]   m_axi_wstrb,
    output                      m_axi_wlast,
    output                      m_axi_wvalid,
    input                       m_axi_wready,

    input  [ID_WIDTH-1:0]       m_axi_bid,
    input  [1:0]                m_axi_bresp,
    input                       m_axi_bvalid,
    output                      m_axi_bready,

    output                      dma_irq
);

localparam [2:0] DMA_IDLE   = 3'd0;
localparam [2:0] DMA_ISSUE  = 3'd1;
localparam [2:0] DMA_STREAM = 3'd2;
localparam [2:0] DMA_WAIT_B = 3'd3;

reg [2:0] dma_state;

wire [ADDR_WIDTH-1:0] src_addr;
wire [ADDR_WIDTH-1:0] dst_addr;
wire [DATA_WIDTH-1:0] burst_len;
wire [DATA_WIDTH-1:0] bytes_len;

wire ctrl_start;
wire ctrl_irq_en;
wire ctrl_clear_done;
wire ctrl_clear_err;

reg [DATA_WIDTH-1:0] status;

reg                   rd_cmd_valid;
wire                  rd_cmd_ready;
reg [ADDR_WIDTH-1:0]  rd_cmd_addr;
reg [8:0]             rd_cmd_beats;

reg                   wr_cmd_valid;
wire                  wr_cmd_ready;
reg [ADDR_WIDTH-1:0]  wr_cmd_addr;
reg [8:0]             wr_cmd_beats;

reg rd_cmd_sent;
reg wr_cmd_sent;

wire rd_cmd_fire;
wire wr_cmd_fire;

wire                  rd_data_valid;
wire                  rd_data_ready;
wire [DATA_WIDTH-1:0] rd_data;
wire                  rd_data_last;
wire [1:0]            rd_data_resp;

wire                  wr_data_valid;
wire                  wr_data_ready;
wire [DATA_WIDTH-1:0] wr_data;
wire [DATA_WIDTH/8-1:0] wr_data_strb;
wire                  wr_data_last;

wire rd_data_fire;
wire wr_data_fire;

wire       wr_resp_valid;
wire       wr_resp_ready;
wire [1:0] wr_resp;
wire       wr_resp_fire;

reg [ADDR_WIDTH-1:0] src_bk;
reg [ADDR_WIDTH-1:0] dst_bk;
reg [DATA_WIDTH-1:0] burst_bk;
reg [DATA_WIDTH-1:0] bytes_bk;
reg                  dma_rd_err;

reg [ADDR_WIDTH-1:0] cur_src_addr;
reg [ADDR_WIDTH-1:0] cur_dst_addr;
reg [8:0]            cur_burst_beats;


assign rd_cmd_fire = rd_cmd_valid && rd_cmd_ready;
assign wr_cmd_fire = wr_cmd_valid && wr_cmd_ready;

assign rd_data_fire = rd_data_valid && rd_data_ready;
assign wr_data_fire = wr_data_valid && wr_data_ready;

assign wr_data_valid = (dma_state == DMA_STREAM) && rd_data_valid;
assign rd_data_ready = (dma_state == DMA_STREAM) && wr_data_ready;

assign wr_data      = rd_data;
assign wr_data_last = rd_data_last;
assign wr_data_strb = {DATA_WIDTH/8{1'b1}};

assign wr_resp_fire  = wr_resp_valid && wr_resp_ready;
assign wr_resp_ready = (dma_state == DMA_WAIT_B);

assign dma_irq = ctrl_irq_en && (status[DMA_STATUS_DONE] || status[DMA_STATUS_ERR]);



function [31:0] byte2beat;
    input [DATA_WIDTH-1:0] byte_count;
    reg [DATA_WIDTH-1:0] round_count;
    begin
        round_count = byte_count + DATA_WIDTH/8 - 1;
        byte2beat   = round_count >> $clog2(DATA_WIDTH/8);
    end
endfunction

lite_config #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
) u_lite_config (
    .clk               (clk),
    .rst_n             (rst_n),

    .s_axil_awaddr     (s_axil_awaddr),
    .s_axil_awvalid    (s_axil_awvalid),
    .s_axil_awready    (s_axil_awready),
    .s_axil_wdata      (s_axil_wdata),
    .s_axil_wstrb      (s_axil_wstrb),
    .s_axil_wvalid     (s_axil_wvalid),
    .s_axil_wready     (s_axil_wready),
    .s_axil_bresp      (s_axil_bresp),
    .s_axil_bvalid     (s_axil_bvalid),
    .s_axil_bready     (s_axil_bready),
    .s_axil_araddr     (s_axil_araddr),
    .s_axil_arvalid    (s_axil_arvalid),
    .s_axil_arready    (s_axil_arready),
    .s_axil_rdata      (s_axil_rdata),
    .s_axil_rresp      (s_axil_rresp),
    .s_axil_rvalid     (s_axil_rvalid),
    .s_axil_rready     (s_axil_rready),

    .status_i          (status),
    .src_addr_o        (src_addr),
    .dst_addr_o        (dst_addr),
    .burst_len_o       (burst_len),
    .bytes_len_o       (bytes_len),
    .ctrl_start_o      (ctrl_start),
    .ctrl_irq_en_o     (ctrl_irq_en),
    .ctrl_clear_done_o (ctrl_clear_done),
    .ctrl_clear_err_o  (ctrl_clear_err)
);

axi_master #(
    .DATA_WIDTH (DATA_WIDTH),
    .ADDR_WIDTH (ADDR_WIDTH),
    .ID_WIDTH   (ID_WIDTH)
) u_axi_master (
    .clk                (clk),
    .rst_n              (rst_n),

    .rd_cmd_valid       (rd_cmd_valid),
    .rd_cmd_ready       (rd_cmd_ready),
    .rd_cmd_addr        (rd_cmd_addr),
    .rd_cmd_beats       (rd_cmd_beats),

    .rd_data_valid      (rd_data_valid),
    .rd_data_ready      (rd_data_ready),
    .rd_data            (rd_data),
    .rd_data_last       (rd_data_last),
    .rd_data_resp       (rd_data_resp),

    .wr_cmd_valid       (wr_cmd_valid),
    .wr_cmd_ready       (wr_cmd_ready),
    .wr_cmd_addr        (wr_cmd_addr),
    .wr_cmd_beats       (wr_cmd_beats),

    .wr_data_valid      (wr_data_valid),
    .wr_data_ready      (wr_data_ready),
    .wr_data            (wr_data),
    .wr_data_strb       (wr_data_strb),
    .wr_data_last       (wr_data_last),

    .wr_resp_valid      (wr_resp_valid),
    .wr_resp_ready      (wr_resp_ready),
    .wr_resp            (wr_resp),

    .m_axi_awid         (m_axi_awid),
    .m_axi_awaddr       (m_axi_awaddr),
    .m_axi_awlen        (m_axi_awlen),
    .m_axi_awsize       (m_axi_awsize),
    .m_axi_awburst      (m_axi_awburst),
    .m_axi_awvalid      (m_axi_awvalid),
    .m_axi_awready      (m_axi_awready),

    .m_axi_wdata        (m_axi_wdata),
    .m_axi_wstrb        (m_axi_wstrb),
    .m_axi_wlast        (m_axi_wlast),
    .m_axi_wvalid       (m_axi_wvalid),
    .m_axi_wready       (m_axi_wready),

    .m_axi_bid          (m_axi_bid),
    .m_axi_bresp        (m_axi_bresp),
    .m_axi_bvalid       (m_axi_bvalid),
    .m_axi_bready       (m_axi_bready),

    .m_axi_araddr       (m_axi_araddr),
    .m_axi_arid         (m_axi_arid),
    .m_axi_arlen        (m_axi_arlen),
    .m_axi_arsize       (m_axi_arsize),
    .m_axi_arburst      (m_axi_arburst),
    .m_axi_arvalid      (m_axi_arvalid),
    .m_axi_arready      (m_axi_arready),

    .m_axi_rid          (m_axi_rid),
    .m_axi_rdata        (m_axi_rdata),
    .m_axi_rresp        (m_axi_rresp),
    .m_axi_rlast        (m_axi_rlast),
    .m_axi_rvalid       (m_axi_rvalid),
    .m_axi_rready       (m_axi_rready)
);


//////DMA top control logic 

wire [31:0] dma_total_beats;
wire        dma_len_zero;


assign dma_total_beats   = byte2beat(bytes_len);
assign dma_len_zero      = (dma_total_beats == 32'd0);


reg [8:0] max_burst_beats;
reg [31:0] remain_beats;

wire [8:0] issue_burst_beats;

assign issue_burst_beats = calc_issue_burst_beats(remain_beats, max_burst_beats);


function [8:0] calc_max_burst_beats;
    input [DATA_WIDTH-1:0] cfg_burst_len;
    begin
        if (cfg_burst_len == 0)
            calc_max_burst_beats = 9'd1;
        else if (cfg_burst_len > 256)
            calc_max_burst_beats = 9'd256;
        else
            calc_max_burst_beats = cfg_burst_len[8:0];
    end
endfunction

function [8:0] calc_issue_burst_beats;
    input [31:0] remain;
    input [8:0]  max_burst;
    begin
        if (remain >= {23'd0, max_burst})
            calc_issue_burst_beats = max_burst;
        else
            calc_issue_burst_beats = remain[8:0];
    end
endfunction

function [ADDR_WIDTH-1:0] beat2byte;
    input [8:0] beats;
    begin
        beat2byte = beats;
        beat2byte = beat2byte << $clog2(DATA_WIDTH/8);
    end
endfunction




always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        dma_state    <= DMA_IDLE;
        src_bk       <= {ADDR_WIDTH{1'b0}};
        dst_bk       <= {ADDR_WIDTH{1'b0}};
        burst_bk     <= {DATA_WIDTH{1'b0}};
        bytes_bk     <= {DATA_WIDTH{1'b0}};
        status       <= {DATA_WIDTH{1'b0}};
        dma_rd_err   <= 1'b0;
        rd_cmd_valid <= 1'b0;
        rd_cmd_addr  <= {ADDR_WIDTH{1'b0}};
        rd_cmd_beats <= 9'd0;
        wr_cmd_valid <= 1'b0;
        wr_cmd_addr  <= {ADDR_WIDTH{1'b0}};
        wr_cmd_beats <= 9'd0;
        rd_cmd_sent  <= 1'b0;
        wr_cmd_sent  <= 1'b0;

        cur_src_addr    <= {ADDR_WIDTH{1'b0}};
        cur_dst_addr    <= {ADDR_WIDTH{1'b0}};
        cur_burst_beats <= 9'd0;
        remain_beats    <= 32'd0;

        max_burst_beats <= 9'd0;
    end
    else begin
        if(ctrl_clear_done)
            status[DMA_STATUS_DONE] <= 1'b0;

        if(ctrl_clear_err)
            status[DMA_STATUS_ERR] <= 1'b0;

        case(dma_state)
            DMA_IDLE: begin
                status[DMA_STATUS_BUSY] <= 1'b0;
                rd_cmd_valid <= 1'b0;
                wr_cmd_valid <= 1'b0;
                rd_cmd_sent  <= 1'b0;
                wr_cmd_sent  <= 1'b0;

                if(ctrl_start)begin
                    src_bk       <= src_addr;
                    dst_bk       <= dst_addr;
                    burst_bk     <= burst_len;
                    bytes_bk     <= bytes_len;
                    max_burst_beats <= calc_max_burst_beats(burst_len);

                    cur_src_addr <= src_addr;
                    cur_dst_addr <= dst_addr;
                    cur_burst_beats <= 9'd0;
                    remain_beats <= dma_total_beats;
                    dma_rd_err   <= 1'b0;

                    if(dma_len_zero)begin
                        status[DMA_STATUS_BUSY] <= 1'b0;
                        status[DMA_STATUS_DONE] <= 1'b1;
                        status[DMA_STATUS_ERR]  <= 1'b0;
                        dma_state               <= DMA_IDLE;
                    end
                    
                   
                    else begin
                        status[DMA_STATUS_BUSY] <= 1'b1;
                        status[DMA_STATUS_DONE] <= 1'b0;
                        status[DMA_STATUS_ERR]  <= 1'b0;

                        dma_state <= DMA_ISSUE;
                    end
                end
            end

            DMA_ISSUE: begin
                if(!rd_cmd_sent)begin
                    rd_cmd_valid <= 1'b1;
                    rd_cmd_addr  <= cur_src_addr;
                    rd_cmd_beats <= issue_burst_beats;
                end
                else begin
                    rd_cmd_valid <= 1'b0;
                end

                if(!wr_cmd_sent)begin
                    wr_cmd_valid <= 1'b1;
                    wr_cmd_addr  <= cur_dst_addr;
                    wr_cmd_beats <= issue_burst_beats;
                end
                else begin
                    wr_cmd_valid <= 1'b0;
                end

                if(rd_cmd_fire)begin
                    rd_cmd_valid <= 1'b0;
                    rd_cmd_sent  <= 1'b1;
                end

                if(wr_cmd_fire)begin
                    wr_cmd_valid <= 1'b0;
                    wr_cmd_sent  <= 1'b1;
                end

                if((rd_cmd_sent || rd_cmd_fire) && (wr_cmd_sent || wr_cmd_fire))begin
                    cur_burst_beats <= issue_burst_beats;
                    rd_cmd_valid    <= 1'b0;
                    wr_cmd_valid    <= 1'b0;
                    rd_cmd_sent     <= 1'b0;
                    wr_cmd_sent     <= 1'b0;
                    dma_state       <= DMA_STREAM;
                end
            end

            DMA_STREAM: begin
                if(rd_data_fire && (rd_data_resp != DMA_RESP_OK))
                    dma_rd_err <= 1'b1;

                if(rd_data_fire && rd_data_last)begin
                    dma_state <= DMA_WAIT_B;
                end
            end

            DMA_WAIT_B: begin
                if(wr_resp_fire)begin
                    if(dma_rd_err || (wr_resp != DMA_RESP_OK) ) begin
                        status[DMA_STATUS_BUSY] <= 1'b0;
                        status[DMA_STATUS_ERR]  <= 1'b1;
                        status[DMA_STATUS_DONE] <= 1'b0;
                        dma_rd_err              <= 1'b0;
                        dma_state               <= DMA_IDLE;

                    end

                    else begin
                        if(remain_beats <= {23'd0, cur_burst_beats})begin
                            remain_beats <= 32'd0;
                            status[DMA_STATUS_BUSY] <= 1'b0;
                            status[DMA_STATUS_ERR]  <= 1'b0;
                            status[DMA_STATUS_DONE] <= 1'b1;

                            dma_state               <= DMA_IDLE;
                        end
                        else begin
                            remain_beats <= remain_beats - {23'd0, cur_burst_beats};
                            cur_src_addr <= cur_src_addr + beat2byte(cur_burst_beats);
                            cur_dst_addr <= cur_dst_addr + beat2byte(cur_burst_beats);

                            status[DMA_STATUS_BUSY] <= 1'b1;
                            status[DMA_STATUS_ERR]  <= 1'b0;
                            status[DMA_STATUS_DONE] <= 1'b0;
                            
                            dma_state               <= DMA_ISSUE;  
                        end
                    end
                end                          

            end

            default: begin
                dma_state <= DMA_IDLE;
            end
        endcase
    end
end




endmodule