`timescale 1ns/1ps

module dma_multi_burst_tb;

localparam ADDR_WIDTH = 32;
localparam DATA_WIDTH = 32;
localparam ID_WIDTH   = 4;
localparam STRB_WIDTH = DATA_WIDTH/8;

localparam [ADDR_WIDTH-1:0] SRC_ADDR   = 32'h0000_0000;
localparam [ADDR_WIDTH-1:0] DST_ADDR   = 32'h0000_0004;
localparam [ADDR_WIDTH-1:0] BURST_LEN  = 32'h0000_0008;
localparam [ADDR_WIDTH-1:0] BYTES_LEN  = 32'h0000_000c;
localparam [ADDR_WIDTH-1:0] CONTROL    = 32'h0000_0010;
localparam [ADDR_WIDTH-1:0] STATUS     = 32'h0000_0014;

localparam START  = 0;
localparam IRQ_EN = 1;
localparam BUSY   = 0;
localparam DONE   = 1;
localparam ERR    = 2;

localparam [1:0] RESP_OK = 2'b00;

reg clk;
reg rst_n;

reg  [ADDR_WIDTH-1:0]   s_axil_awaddr;
reg                     s_axil_awvalid;
wire                    s_axil_awready;
reg  [DATA_WIDTH-1:0]   s_axil_wdata;
reg  [STRB_WIDTH-1:0]   s_axil_wstrb;
reg                     s_axil_wvalid;
wire                    s_axil_wready;
wire [1:0]              s_axil_bresp;
wire                    s_axil_bvalid;
reg                     s_axil_bready;
reg  [ADDR_WIDTH-1:0]   s_axil_araddr;
reg                     s_axil_arvalid;
wire                    s_axil_arready;
wire [DATA_WIDTH-1:0]   s_axil_rdata;
wire [1:0]              s_axil_rresp;
wire                    s_axil_rvalid;
reg                     s_axil_rready;

wire [ID_WIDTH-1:0]     m_axi_arid;
wire [ADDR_WIDTH-1:0]   m_axi_araddr;
wire [7:0]              m_axi_arlen;
wire [2:0]              m_axi_arsize;
wire [1:0]              m_axi_arburst;
wire                    m_axi_arvalid;
reg                     m_axi_arready;
reg  [ID_WIDTH-1:0]     m_axi_rid;
reg  [DATA_WIDTH-1:0]   m_axi_rdata;
reg  [1:0]              m_axi_rresp;
reg                     m_axi_rlast;
reg                     m_axi_rvalid;
wire                    m_axi_rready;

wire [ID_WIDTH-1:0]     m_axi_awid;
wire [ADDR_WIDTH-1:0]   m_axi_awaddr;
wire [7:0]              m_axi_awlen;
wire [2:0]              m_axi_awsize;
wire [1:0]              m_axi_awburst;
wire                    m_axi_awvalid;
reg                     m_axi_awready;
wire [DATA_WIDTH-1:0]   m_axi_wdata;
wire [STRB_WIDTH-1:0]   m_axi_wstrb;
wire                    m_axi_wlast;
wire                    m_axi_wvalid;
reg                     m_axi_wready;
reg  [ID_WIDTH-1:0]     m_axi_bid;
reg  [1:0]              m_axi_bresp;
reg                     m_axi_bvalid;
wire                    m_axi_bready;

wire                    dma_irq;

reg [DATA_WIDTH-1:0] mem [0:2047];

reg [ADDR_WIDTH-1:0] rd_addr_q;
reg [7:0]            rd_len_q;
reg [8:0]            rd_cnt_q;
reg                  rd_active;

reg [ADDR_WIDTH-1:0] wr_addr_q;
reg [7:0]            wr_len_q;
reg [8:0]            wr_cnt_q;
reg                  wr_active;

integer error_count;
integer ar_count;
integer aw_count;
integer r_count;
integer w_count;
integer b_count;

reg [ADDR_WIDTH-1:0] ar_addr_log [0:7];
reg [ADDR_WIDTH-1:0] aw_addr_log [0:7];
reg [7:0]            ar_len_log  [0:7];
reg [7:0]            aw_len_log  [0:7];

dma_axi #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ID_WIDTH(ID_WIDTH)
) u_dut (
    .clk            (clk),
    .rst_n          (rst_n),

    .s_axil_awaddr  (s_axil_awaddr),
    .s_axil_awvalid (s_axil_awvalid),
    .s_axil_awready (s_axil_awready),
    .s_axil_wdata   (s_axil_wdata),
    .s_axil_wstrb   (s_axil_wstrb),
    .s_axil_wvalid  (s_axil_wvalid),
    .s_axil_wready  (s_axil_wready),
    .s_axil_bresp   (s_axil_bresp),
    .s_axil_bvalid  (s_axil_bvalid),
    .s_axil_bready  (s_axil_bready),
    .s_axil_araddr  (s_axil_araddr),
    .s_axil_arvalid (s_axil_arvalid),
    .s_axil_arready (s_axil_arready),
    .s_axil_rdata   (s_axil_rdata),
    .s_axil_rresp   (s_axil_rresp),
    .s_axil_rvalid  (s_axil_rvalid),
    .s_axil_rready  (s_axil_rready),

    .m_axi_arid     (m_axi_arid),
    .m_axi_araddr   (m_axi_araddr),
    .m_axi_arlen    (m_axi_arlen),
    .m_axi_arsize   (m_axi_arsize),
    .m_axi_arburst  (m_axi_arburst),
    .m_axi_arvalid  (m_axi_arvalid),
    .m_axi_arready  (m_axi_arready),
    .m_axi_rid      (m_axi_rid),
    .m_axi_rdata    (m_axi_rdata),
    .m_axi_rresp    (m_axi_rresp),
    .m_axi_rlast    (m_axi_rlast),
    .m_axi_rvalid   (m_axi_rvalid),
    .m_axi_rready   (m_axi_rready),

    .m_axi_awid     (m_axi_awid),
    .m_axi_awaddr   (m_axi_awaddr),
    .m_axi_awlen    (m_axi_awlen),
    .m_axi_awsize   (m_axi_awsize),
    .m_axi_awburst  (m_axi_awburst),
    .m_axi_awvalid  (m_axi_awvalid),
    .m_axi_awready  (m_axi_awready),
    .m_axi_wdata    (m_axi_wdata),
    .m_axi_wstrb    (m_axi_wstrb),
    .m_axi_wlast    (m_axi_wlast),
    .m_axi_wvalid   (m_axi_wvalid),
    .m_axi_wready   (m_axi_wready),
    .m_axi_bid      (m_axi_bid),
    .m_axi_bresp    (m_axi_bresp),
    .m_axi_bvalid   (m_axi_bvalid),
    .m_axi_bready   (m_axi_bready),

    .dma_irq        (dma_irq)
);

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

initial begin
    $fsdbDumpfile("dma_multi_burst_tb.fsdb");
    $fsdbDumpvars(0, dma_multi_burst_tb);
    $fsdbDumpMDA();
end

task check_eq32;
    input [8*64-1:0] name;
    input [31:0] got;
    input [31:0] exp;
    begin
        if(got !== exp)begin
            error_count = error_count + 1;
            $display("[FAIL] %0s got=0x%08x exp=0x%08x time=%0t", name, got, exp, $time);
        end
        else begin
            $display("[PASS] %0s got=0x%08x", name, got);
        end
    end
endtask

task check_eq8;
    input [8*64-1:0] name;
    input [7:0] got;
    input [7:0] exp;
    begin
        if(got !== exp)begin
            error_count = error_count + 1;
            $display("[FAIL] %0s got=0x%02x exp=0x%02x time=%0t", name, got, exp, $time);
        end
        else begin
            $display("[PASS] %0s got=0x%02x", name, got);
        end
    end
endtask

task axil_write;
    input  [ADDR_WIDTH-1:0] addr;
    input  [DATA_WIDTH-1:0] data;
    input  [STRB_WIDTH-1:0] strb;
    output [1:0]            resp;
    integer timeout;
    begin
        timeout = 0;

        @(negedge clk);
        s_axil_awaddr  = addr;
        s_axil_awvalid = 1'b1;
        s_axil_wdata   = data;
        s_axil_wstrb   = strb;
        s_axil_wvalid  = 1'b1;
        s_axil_bready  = 1'b1;

        while(!(s_axil_awready && s_axil_wready) && (timeout < 100))begin
            @(negedge clk);
            timeout = timeout + 1;
        end

        if(timeout >= 100)begin
            error_count = error_count + 1;
            $display("[FAIL] AXI-Lite write timeout waiting AW/W ready addr=0x%08x time=%0t", addr, $time);
            resp = 2'b10;
            s_axil_awvalid = 1'b0;
            s_axil_wvalid  = 1'b0;
            s_axil_bready  = 1'b0;
            s_axil_awaddr  = {ADDR_WIDTH{1'b0}};
            s_axil_wdata   = {DATA_WIDTH{1'b0}};
            s_axil_wstrb   = {STRB_WIDTH{1'b0}};
        end
        else begin
            @(posedge clk);
            @(negedge clk);
            s_axil_awvalid = 1'b0;
            s_axil_wvalid  = 1'b0;

            timeout = 0;
            while(!s_axil_bvalid && (timeout < 100))begin
                @(negedge clk);
                timeout = timeout + 1;
            end

            if(timeout >= 100)begin
                error_count = error_count + 1;
                $display("[FAIL] AXI-Lite write timeout waiting BVALID addr=0x%08x time=%0t", addr, $time);
                resp = 2'b10;
            end
            else begin
                resp = s_axil_bresp;
            end

            @(negedge clk);
            s_axil_bready = 1'b0;
            s_axil_awaddr = {ADDR_WIDTH{1'b0}};
            s_axil_wdata  = {DATA_WIDTH{1'b0}};
            s_axil_wstrb  = {STRB_WIDTH{1'b0}};
        end
    end
endtask

task axil_read;
    input  [ADDR_WIDTH-1:0] addr;
    output [DATA_WIDTH-1:0] data;
    output [1:0]            resp;
    integer timeout;
    begin
        timeout = 0;

        @(negedge clk);
        s_axil_araddr  = addr;
        s_axil_arvalid = 1'b1;
        s_axil_rready  = 1'b1;

        while(!s_axil_arready && (timeout < 100))begin
            @(negedge clk);
            timeout = timeout + 1;
        end

        if(timeout >= 100)begin
            error_count = error_count + 1;
            $display("[FAIL] AXI-Lite read timeout waiting ARREADY addr=0x%08x time=%0t", addr, $time);
            data = 0;
            resp = 2'b10;
            s_axil_arvalid = 1'b0;
            s_axil_rready  = 1'b0;
            s_axil_araddr  = {ADDR_WIDTH{1'b0}};
        end
        else begin
            @(posedge clk);
            @(negedge clk);
            s_axil_arvalid = 1'b0;

            timeout = 0;
            while(!s_axil_rvalid && (timeout < 100))begin
                @(negedge clk);
                timeout = timeout + 1;
            end

            if(timeout >= 100)begin
                error_count = error_count + 1;
                $display("[FAIL] AXI-Lite read timeout waiting RVALID addr=0x%08x time=%0t", addr, $time);
                data = 0;
                resp = 2'b10;
            end
            else begin
                data = s_axil_rdata;
                resp = s_axil_rresp;
            end

            @(negedge clk);
            s_axil_rready = 1'b0;
            s_axil_araddr = {ADDR_WIDTH{1'b0}};
        end
    end
endtask

task init_inputs;
    integer i;
    begin
        s_axil_awaddr  = 0;
        s_axil_awvalid = 0;
        s_axil_wdata   = 0;
        s_axil_wstrb   = 0;
        s_axil_wvalid  = 0;
        s_axil_bready  = 0;
        s_axil_araddr  = 0;
        s_axil_arvalid = 0;
        s_axil_rready  = 0;

        m_axi_arready  = 0;
        m_axi_rid      = 0;
        m_axi_rdata    = 0;
        m_axi_rresp    = RESP_OK;
        m_axi_rlast    = 0;
        m_axi_rvalid   = 0;
        m_axi_awready  = 0;
        m_axi_wready   = 0;
        m_axi_bid      = 0;
        m_axi_bresp    = RESP_OK;
        m_axi_bvalid   = 0;

        rd_addr_q      = 0;
        rd_len_q       = 0;
        rd_cnt_q       = 0;
        rd_active      = 0;
        wr_addr_q      = 0;
        wr_len_q       = 0;
        wr_cnt_q       = 0;
        wr_active      = 0;

        error_count    = 0;
        ar_count       = 0;
        aw_count       = 0;
        r_count        = 0;
        w_count        = 0;
        b_count        = 0;

        for(i = 0; i < 8; i = i + 1)begin
            ar_addr_log[i] = 0;
            aw_addr_log[i] = 0;
            ar_len_log[i]  = 0;
            aw_len_log[i]  = 0;
        end

        for(i = 0; i < 2048; i = i + 1)
            mem[i] = 32'h0;
    end
endtask

task apply_wstrb_to_mem;
    input [ADDR_WIDTH-1:0] byte_addr;
    input [DATA_WIDTH-1:0] data;
    input [STRB_WIDTH-1:0] strb;
    integer i;
    integer word_index;
    begin
        word_index = byte_addr[ADDR_WIDTH-1:2];
        for(i = 0; i < STRB_WIDTH; i = i + 1)begin
            if(strb[i])
                mem[word_index][i*8 +: 8] = data[i*8 +: 8];
        end
    end
endtask

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        m_axi_arready <= 1'b0;
        m_axi_rvalid  <= 1'b0;
        m_axi_rdata   <= {DATA_WIDTH{1'b0}};
        m_axi_rresp   <= RESP_OK;
        m_axi_rlast   <= 1'b0;
        rd_active     <= 1'b0;
        rd_cnt_q      <= 9'd0;
    end
    else begin
        if(!rd_active && !m_axi_rvalid)
            m_axi_arready <= 1'b1;

        if(m_axi_arvalid && m_axi_arready)begin
            rd_active     <= 1'b1;
            m_axi_arready <= 1'b0;
            rd_addr_q     <= m_axi_araddr;
            rd_len_q      <= m_axi_arlen;
            rd_cnt_q      <= 9'd0;

            if(ar_count < 8)begin
                ar_addr_log[ar_count] <= m_axi_araddr;
                ar_len_log[ar_count]  <= m_axi_arlen;
            end
            ar_count <= ar_count + 1;
        end
        else if(rd_active && !m_axi_rvalid)begin
            m_axi_rvalid <= 1'b1;
            m_axi_rdata  <= mem[(rd_addr_q >> 2) + rd_cnt_q];
            m_axi_rresp  <= RESP_OK;
            m_axi_rlast  <= (rd_cnt_q == rd_len_q);
        end
        else if(m_axi_rvalid && m_axi_rready)begin
            r_count <= r_count + 1;
            if(m_axi_rlast)begin
                m_axi_rvalid <= 1'b0;
                m_axi_rlast  <= 1'b0;
                rd_active    <= 1'b0;
            end
            else begin
                m_axi_rvalid <= 1'b0;
                m_axi_rlast  <= 1'b0;
                rd_cnt_q     <= rd_cnt_q + 1'b1;
            end
        end
    end
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        m_axi_awready <= 1'b0;
        m_axi_wready  <= 1'b0;
        m_axi_bvalid  <= 1'b0;
        m_axi_bresp   <= RESP_OK;
        wr_active     <= 1'b0;
        wr_cnt_q      <= 9'd0;
    end
    else begin
        if(!wr_active && !m_axi_bvalid)
            m_axi_awready <= 1'b1;

        if(m_axi_awvalid && m_axi_awready)begin
            wr_active     <= 1'b1;
            m_axi_awready <= 1'b0;
            m_axi_wready  <= 1'b1;
            wr_addr_q     <= m_axi_awaddr;
            wr_len_q      <= m_axi_awlen;
            wr_cnt_q      <= 9'd0;

            if(aw_count < 8)begin
                aw_addr_log[aw_count] <= m_axi_awaddr;
                aw_len_log[aw_count]  <= m_axi_awlen;
            end
            aw_count <= aw_count + 1;
        end

        if(m_axi_wvalid && m_axi_wready)begin
            apply_wstrb_to_mem(wr_addr_q + (wr_cnt_q << 2), m_axi_wdata, m_axi_wstrb);
            w_count <= w_count + 1;

            if(m_axi_wlast)begin
                wr_active    <= 1'b0;
                m_axi_wready <= 1'b0;
                m_axi_bvalid <= 1'b1;
                m_axi_bresp  <= RESP_OK;
                wr_cnt_q     <= 9'd0;
            end
            else begin
                wr_cnt_q <= wr_cnt_q + 1'b1;
            end
        end

        if(m_axi_bvalid && m_axi_bready)begin
            b_count       <= b_count + 1;
            m_axi_bvalid  <= 1'b0;
            m_axi_awready <= 1'b1;
        end
    end
end

initial begin
    reg [1:0] axil_resp;
    reg [31:0] status_data;
    integer i;
    integer done_seen;

    $display("==== DMA multi burst test start ====");

    init_inputs();
    rst_n = 1'b0;
    repeat(5) @(posedge clk);
    rst_n = 1'b1;
    repeat(2) @(posedge clk);

    for(i = 0; i < 10; i = i + 1)
        mem[(32'h0000_0100 >> 2) + i] = 32'h1000_0000 + i;

    axil_write(SRC_ADDR,   32'h0000_0100, 4'hf, axil_resp);
    check_eq32("write SRC resp", {30'd0, axil_resp}, {30'd0, RESP_OK});

    axil_write(DST_ADDR,   32'h0000_0300, 4'hf, axil_resp);
    check_eq32("write DST resp", {30'd0, axil_resp}, {30'd0, RESP_OK});

    axil_write(BURST_LEN,  32'd4, 4'hf, axil_resp);
    check_eq32("write BURST_LEN resp", {30'd0, axil_resp}, {30'd0, RESP_OK});

    axil_write(BYTES_LEN,  32'd40, 4'hf, axil_resp);
    check_eq32("write BYTES_LEN resp", {30'd0, axil_resp}, {30'd0, RESP_OK});

    axil_write(CONTROL, (32'h1 << IRQ_EN) | (32'h1 << START), 4'hf, axil_resp);
    check_eq32("write CONTROL start resp", {30'd0, axil_resp}, {30'd0, RESP_OK});

    done_seen = 0;
    begin : poll_status
        for(i = 0; i < 300; i = i + 1)begin
            axil_read(STATUS, status_data, axil_resp);
            if((status_data[DONE] == 1'b1) || (status_data[ERR] == 1'b1))begin
                done_seen = 1;
                disable poll_status;
            end
        end
    end

    if(!done_seen)begin
        error_count = error_count + 1;
        $display("[FAIL] DMA did not finish within timeout");
    end

    check_eq32("STATUS resp", {30'd0, axil_resp}, {30'd0, RESP_OK});
    check_eq32("STATUS busy", {31'd0, status_data[BUSY]}, 32'd0);
    check_eq32("STATUS done", {31'd0, status_data[DONE]}, 32'd1);
    check_eq32("STATUS err",  {31'd0, status_data[ERR]},  32'd0);
    check_eq32("dma_irq",     {31'd0, dma_irq},            32'd1);

    check_eq32("AR count", ar_count, 32'd3);
    check_eq32("AW count", aw_count, 32'd3);
    check_eq32("R beat count", r_count, 32'd10);
    check_eq32("W beat count", w_count, 32'd10);
    check_eq32("B count", b_count, 32'd3);

    check_eq32("AR addr burst0", ar_addr_log[0], 32'h0000_0100);
    check_eq32("AR addr burst1", ar_addr_log[1], 32'h0000_0110);
    check_eq32("AR addr burst2", ar_addr_log[2], 32'h0000_0120);
    check_eq32("AW addr burst0", aw_addr_log[0], 32'h0000_0300);
    check_eq32("AW addr burst1", aw_addr_log[1], 32'h0000_0310);
    check_eq32("AW addr burst2", aw_addr_log[2], 32'h0000_0320);

    check_eq8("AR len burst0", ar_len_log[0], 8'd3);
    check_eq8("AR len burst1", ar_len_log[1], 8'd3);
    check_eq8("AR len burst2", ar_len_log[2], 8'd1);
    check_eq8("AW len burst0", aw_len_log[0], 8'd3);
    check_eq8("AW len burst1", aw_len_log[1], 8'd3);
    check_eq8("AW len burst2", aw_len_log[2], 8'd1);

    for(i = 0; i < 10; i = i + 1)begin
        check_eq32("DST data", mem[(32'h0000_0300 >> 2) + i], 32'h1000_0000 + i);
    end

    if(error_count == 0)
        $display("==== DMA multi burst test PASSED ====");
    else
        $display("==== DMA multi burst test FAILED: %0d error(s) ====", error_count);

    $finish;
end

endmodule