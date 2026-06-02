module dma_axi #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4
)(
    input                       aclk,
    input                       aresetn,

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

endmodule