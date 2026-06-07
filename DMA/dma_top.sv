`timescale 1ns/1ps

module dma_axi #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4
)(
    input                       clk,
    input                       rst_n,

    // =========================================================
    // AXI-Lite Slave Interface
    // CPU uses this interface to configure DMA registers
    // =========================================================
    input  [ADDR_WIDTH-1:0]     s_axil_awaddr,
    input                       s_axil_awvalid,
    output                      s_axil_awready,

    input  [DATA_WIDTH-1:0]     s_axil_wdata,
    input  [DATA_WIDTH/8-1:0]   s_axil_wstrb,
    input                       s_axil_wvalid,
    output                      s_axil_wready,

    output reg [1:0]            s_axil_bresp,
    output                     s_axil_bvalid,
    input                       s_axil_bready,

    input  [ADDR_WIDTH-1:0]     s_axil_araddr,
    input                       s_axil_arvalid,
    output                      s_axil_arready,

    output reg [DATA_WIDTH-1:0]     s_axil_rdata,
    output reg [1:0]                s_axil_rresp,
    output                      s_axil_rvalid,
    input                       s_axil_rready,

    // =========================================================
    // AXI4 Master Read Address Channel
    // DMA reads data from memory or NPU output buffer
    // =========================================================
    output [ID_WIDTH-1:0]       m_axi_arid,
    output [ADDR_WIDTH-1:0]     m_axi_araddr,
    output [7:0]                m_axi_arlen,
    output [2:0]                m_axi_arsize,
    output [1:0]                m_axi_arburst,
    output                      m_axi_arvalid,
    input                       m_axi_arready,

    // =========================================================
    // AXI4 Master Read Data Channel
    // =========================================================
    input  [ID_WIDTH-1:0]       m_axi_rid,
    input  [DATA_WIDTH-1:0]     m_axi_rdata,
    input  [1:0]                m_axi_rresp,
    input                       m_axi_rlast,
    input                       m_axi_rvalid,
    output                      m_axi_rready,

    // =========================================================
    // AXI4 Master Write Address Channel
    // DMA writes data to memory or NPU input buffer
    // =========================================================
    output [ID_WIDTH-1:0]       m_axi_awid,
    output [ADDR_WIDTH-1:0]     m_axi_awaddr,
    output [7:0]                m_axi_awlen,
    output [2:0]                m_axi_awsize,
    output [1:0]                m_axi_awburst,
    output                      m_axi_awvalid,
    input                       m_axi_awready,

    // =========================================================
    // AXI4 Master Write Data Channel
    // =========================================================
    output [DATA_WIDTH-1:0]     m_axi_wdata,
    output [DATA_WIDTH/8-1:0]   m_axi_wstrb,
    output                      m_axi_wlast,
    output                      m_axi_wvalid,
    input                       m_axi_wready,

    // =========================================================
    // AXI4 Master Write Response Channel
    // =========================================================
    input  [ID_WIDTH-1:0]       m_axi_bid,
    input  [1:0]                m_axi_bresp,
    input                       m_axi_bvalid,
    output                      m_axi_bready,

    // =========================================================
    // Interrupt
    // =========================================================
    output                      dma_irq
);

//config registers
reg [ADDR_WIDTH-1:0]            src_addr;
reg [ADDR_WIDTH-1:0]            dst_addr;
reg [DATA_WIDTH-1:0]            burst_len;    //total beat number for single burst
reg [DATA_WIDTH-1:0]            bytes_len;  //  total byte number for this DMA transistion
reg [DATA_WIDTH-1:0]            control; 
reg [DATA_WIDTH-1:0]            status;

//addr maped  ADDR offset 
localparam [ADDR_WIDTH-1:0] SRC_ADDR='h00;
localparam [ADDR_WIDTH-1:0] DST_ADDR='h04;
localparam [ADDR_WIDTH-1:0] BURST_LEN='h08;
localparam [ADDR_WIDTH-1:0] BYTES_LEN='h0C;
localparam [ADDR_WIDTH-1:0] CONTROL='h10;
localparam [ADDR_WIDTH-1:0] STATUS='h14;

//contro bit definitions
localparam START=0;
localparam IRQ_EN=1;
localparam CLEAR_DONE=2;
localparam CLEAR_ERR=3;

//status bit definitions
localparam BUSY=0;
localparam DONE=1;
localparam ERR=2;


// =========================================================
// state definitions
// =========================================================

localparam [1:0] WR_IDLE=2'd0;
localparam [1:0] WR_COLLECT=2'd1;
localparam [1:0] WR_RESP=2'd2;

localparam       RD_IDLE=1'b0;
localparam       RD_RESP=1'b1;

localparam [1:0]  RESP_OK=2'b00;
localparam [1:0]  RESP_SLVERR=2'b10;  


wire aw_fire,w_fire,b_fire,ar_fire ,r_fire;

assign aw_fire = s_axil_awvalid && s_axil_awready;
assign w_fire  = s_axil_wvalid  && s_axil_wready;
assign b_fire  = s_axil_bvalid  && s_axil_bready;       
assign ar_fire = s_axil_arvalid && s_axil_arready;
assign r_fire  = s_axil_rvalid  && s_axil_rready;

// =========================================================
// read task
// =========================================================

task reg_read;
    input  [ADDR_WIDTH-1:0]  addr;
    output [DATA_WIDTH-1:0]  data;
    output [1:0] resp;

    begin
            data=0;
            resp=RESP_OK;
        case(addr[7:0])
            SRC_ADDR:begin
                data=src_addr;

            end
            DST_ADDR:begin
                data=dst_addr;

            end
            BURST_LEN:begin
                data=burst_len;
             
            end
            BYTES_LEN:begin
                data=bytes_len;
            end
            CONTROL:begin
                data=control;
            end
            STATUS:begin
                data=status;
            end
            default:begin
               data=0;
                resp=RESP_SLVERR;
            end
        endcase
    end
endtask

reg [DATA_WIDTH-1:0] rdata_next;
reg [1:0]            rresp_next;

always@(*)begin
    reg_read(s_axil_araddr,rdata_next,rresp_next);
end

// =========================================================
// write task
// =========================================================

function [DATA_WIDTH-1:0] apply_wstrb;
    input [DATA_WIDTH-1:0] old_data;
    input [DATA_WIDTH-1:0] wdata;
    input [DATA_WIDTH/8-1:0] wstrb;

    integer i;
    begin
        apply_wstrb=old_data;
        for(i=0;i<DATA_WIDTH/8;i=i+1)begin
            if(wstrb[i])begin
                apply_wstrb[i*8 +: 8]=wdata[i*8 +: 8];
            end
        end
    end
endfunction

task reg_write;
    input  [ADDR_WIDTH-1:0]  addr;
    input  [DATA_WIDTH-1:0]  wdata;
    input  [DATA_WIDTH/8-1:0] wstrb;
    output [1:0] resp;

    begin
        resp=RESP_OK;
        case(addr[7:0])
            SRC_ADDR:begin
                src_addr<=apply_wstrb(src_addr,wdata,wstrb);
            end
            DST_ADDR:begin
                dst_addr<=apply_wstrb(dst_addr,wdata,wstrb);
            end
            BURST_LEN:begin
                burst_len<=apply_wstrb(burst_len,wdata,wstrb);
            end
            BYTES_LEN:begin
                bytes_len<=apply_wstrb(bytes_len,wdata,wstrb);
            end
            CONTROL:begin
                control<=apply_wstrb(control,wdata,wstrb);
            end
            default:begin
                resp=RESP_SLVERR;
            end
        endcase
    end
endtask




// =========================================================
// write state machine
// =========================================================

reg [1:0] wr_state;
reg [ADDR_WIDTH-1:0] awaddr_reg;
reg [DATA_WIDTH-1:0] wdata_reg;
reg [DATA_WIDTH/8-1:0] wstrb_reg;
reg                    aw_seen;
reg                    w_seen;

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        wr_state<=WR_IDLE;
        awaddr_reg<=0;
        wdata_reg<=0;
        wstrb_reg<=0;
        aw_seen<=0;
        w_seen<=0;
        src_addr     <= 0;
        dst_addr     <= 0;
        burst_len    <= 0;
        bytes_len    <= 0;
        control      <= 0;
        s_axil_bresp   <= RESP_OK;
    end
    else begin
        case(wr_state)

            WR_IDLE,
            WR_COLLECT:begin
                
                if(aw_fire)begin
                    awaddr_reg<=s_axil_awaddr;
                    aw_seen<=1;
                end
                if(w_fire)begin
                    wdata_reg<=s_axil_wdata;
                    wstrb_reg<=s_axil_wstrb;
                    w_seen<=1;
                
                end
                if((aw_fire || aw_seen) && (w_fire || w_seen))begin

                      reg_write(
                        aw_fire ? s_axil_awaddr : awaddr_reg,
                        w_fire  ? s_axil_wdata  : wdata_reg,
                        w_fire  ? s_axil_wstrb  : wstrb_reg,
                        s_axil_bresp
                    );
                    aw_seen<=0;
                    w_seen<=0;
                    wr_state<=WR_RESP;

                end else if(aw_fire || w_fire)begin
                    wr_state<=WR_COLLECT;
                end                   

            end
            WR_RESP:begin
                if(b_fire)begin
                    wr_state<=WR_IDLE;
                end
                
            end
            default:begin
                wr_state<=WR_IDLE;
            end
        endcase
    end

end


// =========================================================
// read FSM
// =========================================================

reg rd_state;


always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        rd_state<=RD_IDLE;
        s_axil_rdata<=0;
        s_axil_rresp<=RESP_OK;
    end
    else begin
        case(rd_state)
            RD_IDLE:begin
                if(ar_fire)begin
                    s_axil_rdata<=rdata_next;
                    s_axil_rresp<=rresp_next;
                    rd_state<=RD_RESP;
                end
            end
            RD_RESP:begin
                if(r_fire)begin
                    rd_state<=RD_IDLE;
                end
            end
            default:begin
                rd_state<=RD_IDLE;
            end
        endcase
    end
end

// =========================================================
// axi-lite slave valid_ready logic
// =========================================================

assign s_axil_awready = (wr_state != WR_RESP) && (!aw_seen);
assign s_axil_wready  = (wr_state != WR_RESP) && (!w_seen);
assign s_axil_bvalid  = (wr_state == WR_RESP);

assign s_axil_arready = (rd_state == RD_IDLE);
assign s_axil_rvalid  = (rd_state == RD_RESP);

// =========================================================
// DMA main-control FSM state
// =========================================================

localparam [2:0] DMA_IDLE   = 3'd0;
localparam [2:0] DMA_ISSUE  = 3'd1;
localparam [2:0] DMA_STREAM = 3'd2;
localparam [2:0] DMA_WAIT_B = 3'd3;

reg [2:0] dma_state;

// =========================================================
//  AXI-FULL Master
// =========================================================

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

assign rd_cmd_fire = rd_cmd_valid && rd_cmd_ready;
assign wr_cmd_fire = wr_cmd_valid && wr_cmd_ready;

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

assign rd_data_fire = rd_data_valid && rd_data_ready;
assign wr_data_fire = wr_data_valid && wr_data_ready;

assign wr_data_valid = (dma_state == DMA_STREAM) && rd_data_valid;
assign rd_data_ready = (dma_state == DMA_STREAM) && wr_data_ready;

assign wr_data      = rd_data;
assign wr_data_last = rd_data_last;
assign wr_data_strb = {DATA_WIDTH/8{1'b1}};

wire       wr_resp_valid;
wire       wr_resp_ready;
wire [1:0] wr_resp;

wire       wr_resp_fire;

assign wr_resp_fire = wr_resp_valid && wr_resp_ready;
assign wr_resp_ready = (dma_state == DMA_WAIT_B);

assign dma_irq = control[IRQ_EN] && (status[DONE] || status[ERR]);

axi_master #(
    .DATA_WIDTH (DATA_WIDTH),
    .ADDR_WIDTH (ADDR_WIDTH),
    .ID_WIDTH   (ID_WIDTH)
) u_axi_master (
    .clk                (clk),
    .rst_n              (rst_n),

    // Read command
    .rd_cmd_valid       (rd_cmd_valid),
    .rd_cmd_ready       (rd_cmd_ready),
    .rd_cmd_addr        (rd_cmd_addr),
    .rd_cmd_beats       (rd_cmd_beats),

    // Read data return
    .rd_data_valid      (rd_data_valid),
    .rd_data_ready      (rd_data_ready),
    .rd_data            (rd_data),
    .rd_data_last       (rd_data_last),
    .rd_data_resp       (rd_data_resp),

    // Write command
    .wr_cmd_valid       (wr_cmd_valid),
    .wr_cmd_ready       (wr_cmd_ready),
    .wr_cmd_addr        (wr_cmd_addr),
    .wr_cmd_beats       (wr_cmd_beats),

    // Write data
    .wr_data_valid      (wr_data_valid),
    .wr_data_ready      (wr_data_ready),
    .wr_data            (wr_data),
    .wr_data_strb       (wr_data_strb),
    .wr_data_last       (wr_data_last),

    // Write response
    .wr_resp_valid      (wr_resp_valid),
    .wr_resp_ready      (wr_resp_ready),
    .wr_resp            (wr_resp),

    // AXI write address channel
    .m_axi_awid         (m_axi_awid),
    .m_axi_awaddr       (m_axi_awaddr),
    .m_axi_awlen        (m_axi_awlen),
    .m_axi_awsize       (m_axi_awsize),
    .m_axi_awburst      (m_axi_awburst),
    .m_axi_awvalid      (m_axi_awvalid),
    .m_axi_awready      (m_axi_awready),

    // AXI write data channel
    .m_axi_wdata        (m_axi_wdata),
    .m_axi_wstrb        (m_axi_wstrb),
    .m_axi_wlast        (m_axi_wlast),
    .m_axi_wvalid       (m_axi_wvalid),
    .m_axi_wready       (m_axi_wready),

    // AXI write response channel
    .m_axi_bid          (m_axi_bid),
    .m_axi_bresp        (m_axi_bresp),
    .m_axi_bvalid       (m_axi_bvalid),
    .m_axi_bready       (m_axi_bready),

    // AXI read address channel
    .m_axi_araddr       (m_axi_araddr),
    .m_axi_arid         (m_axi_arid),
    .m_axi_arlen        (m_axi_arlen),
    .m_axi_arsize       (m_axi_arsize),
    .m_axi_arburst      (m_axi_arburst),
    .m_axi_arvalid      (m_axi_arvalid),
    .m_axi_arready      (m_axi_arready),

    // AXI read data channel
    .m_axi_rid          (m_axi_rid),
    .m_axi_rdata        (m_axi_rdata),
    .m_axi_rresp        (m_axi_rresp),
    .m_axi_rlast        (m_axi_rlast),
    .m_axi_rvalid       (m_axi_rvalid),
    .m_axi_rready       (m_axi_rready)
);


// =========================================================
// DMA main-control FSM
// =========================================================

reg [ADDR_WIDTH-1:0]            src_bk;   //reserve config register 
reg [ADDR_WIDTH-1:0]            dst_bk;
reg [DATA_WIDTH-1:0]            burst_bk;
reg [DATA_WIDTH-1:0]            bytes_bk;

// start posedge detect
reg  start_pre;   //reserve start result of pre-clk 
wire start_edge;

reg  dma_rd_err;

always@(posedge clk  or negedge rst_n)begin
    if(!rst_n)begin
        start_pre<=0;
    end
    else begin
        start_pre<=control[START];
    end
end

assign start_edge=control[START] && !start_pre;


function [31:0] byte2beat;    // calculate need how many beats,if byte=5,need 2beats;
    input[DATA_WIDTH-1:0] byte_count;
    reg [DATA_WIDTH-1:0] round_count;
    begin
        round_count=byte_count+ DATA_WIDTH/8-1;
        byte2beat=round_count>>$clog2(DATA_WIDTH/8);
    end
endfunction

wire [31:0] dma_total_beats;
wire        dma_len_zero;
wire        dma_len_too_large;

assign dma_total_beats    = byte2beat(bytes_len);
assign dma_len_zero       = (dma_total_beats == 32'd0);
assign dma_len_too_large  = (dma_total_beats > 32'd256);

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        dma_state<=DMA_IDLE;
        src_bk<=0;  
        dst_bk<=0;
        burst_bk<=0;
        bytes_bk<=0;

        status<=0;

        dma_rd_err<=0;


        rd_cmd_valid <=0;
        rd_cmd_addr  <=0; 
        rd_cmd_beats <=0;

        wr_cmd_valid <=0;
        wr_cmd_addr  <=0; 
        wr_cmd_beats <=0; 

        rd_cmd_sent<=0;   //rd_cmd and wr_cmd may be accepted in different cycle,so need record whether cmd has been sent
        wr_cmd_sent<=0;      
    end
    else begin
        case(dma_state) 
            DMA_IDLE:if(start_edge)begin
                        
                        src_bk  <=src_addr;  
                        dst_bk  <=dst_addr;
                        burst_bk<=burst_len;
                        bytes_bk<=bytes_len; 

                        rd_cmd_valid <= 1'b0;
                        wr_cmd_valid <= 1'b0;
                        rd_cmd_sent  <= 1'b0;
                        wr_cmd_sent  <= 1'b0;
                        dma_rd_err   <= 1'b0;

                        if(dma_len_zero)begin
                            status[BUSY] <= 1'b0;
                            status[DONE] <= 1'b1;
                            status[ERR]  <= 1'b0;
                            dma_state    <= DMA_IDLE;
                        end
                        else if(dma_len_too_large)begin
                            status[BUSY] <= 1'b0;
                            status[DONE] <= 1'b0;
                            status[ERR]  <= 1'b1;
                            dma_state    <= DMA_IDLE;
                        end
                        else begin
                        
                            status[BUSY] <=1;
                            status[DONE] <=0;
                            status[ERR]  <=0;
                                              
                            rd_cmd_valid <= 1'b1;
                            rd_cmd_addr  <= src_addr;
                            rd_cmd_beats <= dma_total_beats[8:0];

                            wr_cmd_valid <= 1'b1;
                            wr_cmd_addr  <= dst_addr;
                            wr_cmd_beats <= dma_total_beats[8:0];

                            dma_state <= DMA_ISSUE;
                        end


                    end
            DMA_ISSUE:begin
                        if(rd_cmd_fire)begin
                            rd_cmd_valid<=1'b0;
                            rd_cmd_sent<=1'b1;
                        end

                        if(wr_cmd_fire)begin
                            wr_cmd_valid<=1'b0;
                            wr_cmd_sent<=1'b1;
                        end
                        if((rd_cmd_sent || rd_cmd_fire) && (wr_cmd_sent || wr_cmd_fire))begin
                            dma_state <=DMA_STREAM;
                        end
            end

            DMA_STREAM:begin 
                        if(rd_data_fire && (rd_data_resp!=RESP_OK))begin
                            dma_rd_err<=1'b1;
                        end

                        if(rd_data_fire && rd_data_last)begin
                                    dma_state <=DMA_WAIT_B;
                                end
                        
            end

             DMA_WAIT_B:begin
                            
                            if(wr_resp_fire)begin
                                dma_state <=DMA_IDLE;
                                status[BUSY] <=0;
                                if((wr_resp==RESP_OK) && !dma_rd_err)begin
                                     status[DONE] <=1;
                                     status[ERR]<=1'b0;
                            
                                end
                                else begin
                                    status[ERR]<=1'b1;
                                    status[DONE] <=1'b0;
                                end
                                
                            end
             end
            default: dma_state <=DMA_IDLE;
        
 
        endcase
    end
end















endmodule
