`timescale 1ns/1ps
module lite_slave #(
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
    input                       s_axil_rready

    // =========================================================
    // AXI4 Master Read Address Channel
    // DMA reads data from memory or NPU output buffer
    // =========================================================
/*     output [ID_WIDTH-1:0]       m_axi_arid,
    output [ADDR_WIDTH-1:0]     m_axi_araddr,
    output [7:0]                m_axi_arlen,
    output [2:0]                m_axi_arsize,
    output [1:0]                m_axi_arburst,
    output                      m_axi_arvalid,
    input                       m_axi_arready,
 */
    // =========================================================
    // AXI4 Master Read Data Channel
    // =========================================================
/*     input  [ID_WIDTH-1:0]       m_axi_rid,
    input  [DATA_WIDTH-1:0]     m_axi_rdata,
    input  [1:0]                m_axi_rresp,
    input                       m_axi_rlast,
    input                       m_axi_rvalid,
    output                      m_axi_rready, */

    // =========================================================
    // AXI4 Master Write Address Channel
    // DMA writes data to memory or NPU input buffer
    // =========================================================
/*     output [ID_WIDTH-1:0]       m_axi_awid,
    output [ADDR_WIDTH-1:0]     m_axi_awaddr,
    output [7:0]                m_axi_awlen,
    output [2:0]                m_axi_awsize,
    output [1:0]                m_axi_awburst,
    output                      m_axi_awvalid,
    input                       m_axi_awready, */

    // =========================================================
    // AXI4 Master Write Data Channel
    // =========================================================
/*     output [DATA_WIDTH-1:0]     m_axi_wdata,
    output [DATA_WIDTH/8-1:0]   m_axi_wstrb,
    output                      m_axi_wlast,
    output                      m_axi_wvalid,
    input                       m_axi_wready,
 */
    // =========================================================
    // AXI4 Master Write Response Channel
    // =========================================================
/*     input  [ID_WIDTH-1:0]       m_axi_bid,
    input  [1:0]                m_axi_bresp,
    input                       m_axi_bvalid,
    output                      m_axi_bready,
 */
    // =========================================================
    // Interrupt
    // =========================================================
    /* output                      dma_irq */
);

//config registers
reg [ADDR_WIDTH-1:0]            src_addr;
reg [ADDR_WIDTH-1:0]            dst_addr;
reg [DATA_WIDTH-1:0]            burst_len;
reg [DATA_WIDTH-1:0]            bytes_len;
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








endmodule