module axi_master #(
    parameter  DATA_WIDTH=32,
    parameter  ADDR_WIDTH=32,
    parameter  ID_WIDTH=4       //for multi outstanding
)(
    input                   clk,
    input                   rst_n,

    //evoke a burst read from top

    input                       rd_cmd_valid,
    output                       rd_cmd_ready,
    input[ADDR_WIDTH-1:0]       rd_cmd_addr,
    input[8:0]                  rd_cmd_beats,

    //return read data to top

    output                      rd_data_valid,
    input                       rd_data_ready,
    output[DATA_WIDTH-1:0]      rd_data,
    output                      rd_data_last,
    output[1:0]                 rd_data_resp,

    //evoke write from top

    input                       wr_cmd_valid,
    output                       wr_cmd_ready,
    input[ADDR_WIDTH-1:0]       wr_cmd_addr,
    input[8:0]                  wr_cmd_beats,  

    //write  data from top

    input                        wr_data_valid,
    output                       wr_data_ready,
    input[DATA_WIDTH-1:0]      wr_data,
    input[DATA_WIDTH/8-1:0]    wr_data_strb,
    input                      wr_data_last,

    //wr response return to top

    output                      wr_resp_valid,
    input                       wr_resp_ready,
    output [1:0]                wr_resp,


    //AXI full master interface

    output[ID_WIDTH-1:0]                m_axi_awid,
    output reg[ADDR_WIDTH-1:0]          m_axi_awaddr,
    output reg[7:0]                     m_axi_awlen,
    output[2:0]                         m_axi_awsize,
    output[1:0]                         m_axi_awburst,
    output reg                          m_axi_awvalid,
    input                               m_axi_awready,


    //AXI master write data channel

    output[DATA_WIDTH-1:0]      m_axi_wdata,
    output[DATA_WIDTH/8-1:0]    m_axi_wstrb,
    output                      m_axi_wlast,
    output                      m_axi_wvalid,
    input                       m_axi_wready,

    //wirte response channel B

    input[ID_WIDTH-1:0]         m_axi_bid,
    input[1:0]                  m_axi_bresp,
    input                       m_axi_bvalid,
    output                      m_axi_bready,

    //read addr:AR
    output reg[ADDR_WIDTH-1:0]      m_axi_araddr,
    output[ID_WIDTH-1:0]            m_axi_arid,
    output reg [7:0]                m_axi_arlen,
    output[2:0]                     m_axi_arsize,
    output[1:0]                     m_axi_arburst,
    output reg                      m_axi_arvalid,
    input                           m_axi_arready,

    ///R channel

    input[ID_WIDTH-1:0]         m_axi_rid,
    input[DATA_WIDTH-1:0]       m_axi_rdata,
    input[1:0]                  m_axi_rresp,
    input                       m_axi_rlast,
    input                       m_axi_rvalid,
    output                      m_axi_rready


);

localparam  AXI_ID={ID_WIDTH{1'b0}};
localparam  AXI_SIZE=$clog2(DATA_WIDTH/8);
localparam  AXI_BURST=2'b01;   //fixed increment burst

localparam  WR_IDLE=2'b00;
localparam  WR_ADDR=2'b01;
localparam  WR_DATA=2'b10;
localparam  WR_RESP=2'b11;

localparam  RD_IDLE=2'b00;
localparam  RD_ADDR=2'b01;
localparam  RD_DATA=2'b10;

wire wr_cmd_fire;
wire rd_cmd_fire;
wire aw_fire, w_fire, b_fire, ar_fire, r_fire;

assign m_axi_awid=AXI_ID;
assign m_axi_awsize=AXI_SIZE;
assign m_axi_awburst=AXI_BURST;


assign m_axi_arid=AXI_ID;
assign m_axi_arsize=AXI_SIZE;
assign m_axi_arburst=AXI_BURST;

assign wr_cmd_fire=wr_cmd_valid & wr_cmd_ready;
assign rd_cmd_fire=rd_cmd_valid & rd_cmd_ready;

assign aw_fire=m_axi_awvalid & m_axi_awready;
assign w_fire=m_axi_wvalid & m_axi_wready;
assign b_fire=m_axi_bvalid & m_axi_bready;
assign ar_fire=m_axi_arvalid & m_axi_arready;
assign r_fire=m_axi_rvalid & m_axi_rready;


reg[2:0] wr_state;
reg[2:0] rd_state;
reg[7:0] wr_cnt;
reg[8:0] wr_beat;
reg[7:0] rd_cnt;
reg[8:0] rd_beat;

//write channe FSM

assign m_axi_wdata=wr_data;
assign m_axi_wstrb=wr_data_strb;
assign m_axi_wvalid=(wr_state==WR_DATA)&& wr_data_valid;
assign m_axi_wlast=(wr_state==WR_DATA)&&(wr_cnt==wr_beat-1);

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        wr_state<=WR_IDLE;
        m_axi_awaddr<=0;
        m_axi_awlen<=0;
        m_axi_awvalid<=0;
        wr_cnt<=0;
        wr_beat<=0;
    end
    else begin
        case(wr_state)
            WR_IDLE:begin
                wr_cnt<=0;
                if(wr_cmd_fire &(wr_cmd_beats!=0))begin
                        m_axi_awaddr<=wr_cmd_addr;
                        m_axi_awlen<=wr_cmd_beats[7:0]-1;
                        m_axi_awvalid<=1'b1;
                        wr_state<=WR_ADDR;
                        wr_beat<=wr_cmd_beats;
                        wr_cnt<=0;
                    end
            end
                   
            WR_ADDR:if(aw_fire)begin
                        wr_state<=WR_DATA;
                        m_axi_awvalid<=0;
            end
                    
            WR_DATA:if(w_fire)begin
                        wr_cnt<=wr_cnt+1;
                        if(m_axi_wlast)
                            wr_state<=WR_RESP;
            end

            WR_RESP:if(b_fire)
                        wr_state<=WR_IDLE;
            default:
                    wr_state<=WR_IDLE;
        endcase
    end
end
                       
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        m_axi_araddr<=0;
        m_axi_arvalid<=0;
        m_axi_arlen<=0;
        rd_state<=RD_IDLE;
        rd_cnt<=0;
        rd_beat<=0;
    end
    else begin
        case(rd_state)
            RD_IDLE:begin
                rd_cnt<=0;
                if(rd_cmd_fire&(rd_cmd_beats!=0))begin
                        m_axi_araddr<=rd_cmd_addr;
                        m_axi_arlen<=rd_cmd_beats[7:0]-1;
                        m_axi_arvalid<=1'b1;
                        rd_state<=RD_ADDR;
                        rd_beat<=rd_cmd_beats;
            end
            end
            RD_ADDR:if(ar_fire)begin
                        m_axi_arvalid<=1'b0;
                        rd_state<=RD_DATA;
            end
            RD_DATA:if(r_fire)begin
                        rd_cnt<=rd_cnt+1;
                        if(m_axi_rlast)
                        rd_state<=RD_IDLE;
            end
            default:rd_state<=RD_IDLE;
        endcase
    end
end

assign m_axi_bready  = (wr_state == WR_RESP) && wr_resp_ready;
assign m_axi_rready=(rd_state==RD_DATA)&& rd_data_ready;

assign rd_data_valid = (rd_state == RD_DATA) && m_axi_rvalid;
assign rd_data       = m_axi_rdata;
assign rd_data_last  = m_axi_rlast;
assign rd_data_resp  = m_axi_rresp;
assign wr_data_ready = (wr_state == WR_DATA) && m_axi_wready;
assign wr_resp_valid = (wr_state == WR_RESP) && m_axi_bvalid;
assign wr_resp       = m_axi_bresp;
assign wr_cmd_ready = (wr_state == WR_IDLE);
assign rd_cmd_ready = (rd_state == RD_IDLE);

endmodule