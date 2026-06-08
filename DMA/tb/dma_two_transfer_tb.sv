`timescale 1ns/1ps

module dma_two_transfer_tb;

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

localparam START      = 0;
localparam IRQ_EN     = 1;
localparam CLEAR_DONE = 2;
localparam CLEAR_ERR  = 3;

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

reg [DATA_WIDTH-1:0] mem [0:1023];

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

reg [ADDR_WIDTH-1:0] last_araddr;
reg [ADDR_WIDTH-1:0] last_awaddr;
reg [7:0]            last_arlen;
reg [7:0]            last_awlen;

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
    $fsdbDumpfile("dma_two_transfer_tb.fsdb");
    $fsdbDumpvars(0, dma_two_transfer_tb);
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
        last_araddr    = 0;
        last_awaddr    = 0;
        last_arlen     = 0;
        last_awlen     = 0;

        for(i = 0; i < 1024; i = i + 1)
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
            ar_count      <= ar_count + 1;
            last_araddr   <= m_axi_araddr;
            last_arlen    <= m_axi_arlen;
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
            aw_count      <= aw_count + 1;
            last_awaddr   <= m_axi_awaddr;
            last_awlen    <= m_axi_awlen;
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

task wait_dma_done;
    output [31:0] status_data;
    integer i;
    integer done_seen;
    reg [1:0] resp;
    begin
        done_seen = 0;
        status_data = 0;

        begin : poll_status
            for(i = 0; i < 200; i = i + 1)begin
                axil_read(STATUS, status_data, resp);
                if((status_data[DONE] == 1'b1) || (status_data[ERR] == 1'b1))begin
                    done_seen = 1;
                    disable poll_status;
                end
            end
        end

        if(!done_seen)begin
            error_count = error_count + 1;
            $display("[FAIL] DMA did not finish within timeout time=%0t", $time);
        end
    end
endtask

initial begin
    reg [1:0] axil_resp;
    reg [31:0] status_data;
    reg [31:0] control_data;

    $display("==== DMA two-transfer test start ====");

    init_inputs();
    rst_n = 1'b0;
    repeat(5) @(posedge clk);
    rst_n = 1'b1;
    repeat(2) @(posedge clk);

    mem[32'h0000_0100 >> 2] = 32'h1111_0000;
    mem[32'h0000_0104 >> 2] = 32'h2222_0001;
    mem[32'h0000_0108 >> 2] = 32'h3333_0002;
    mem[32'h0000_010c >> 2] = 32'h4444_0003;

    mem[32'h0000_0300 >> 2] = 32'haaaa_1000;
    mem[32'h0000_0304 >> 2] = 32'hbbbb_1001;
    mem[32'h0000_0308 >> 2] = 32'hcccc_1002;
    mem[32'h0000_030c >> 2] = 32'hdddd_1003;
    mem[32'h0000_0310 >> 2] = 32'heeee_1004;
    mem[32'h0000_0314 >> 2] = 32'hffff_1005;
    mem[32'h0000_0318 >> 2] = 32'h1234_1006;
    mem[32'h0000_031c >> 2] = 32'h5678_1007;

    axil_write(SRC_ADDR, 32'h0000_0100, 4'hf, axil_resp);
    check_eq32("transfer0 write SRC resp", {30'd0, axil_resp}, {30'd0, RESP_OK});
    axil_write(DST_ADDR, 32'h0000_0200, 4'hf, axil_resp);
    check_eq32("transfer0 write DST resp", {30'd0, axil_resp}, {30'd0, RESP_OK});
    axil_write(BYTES_LEN, 32'd16, 4'hf, axil_resp);
    check_eq32("transfer0 write BYTES_LEN resp", {30'd0, axil_resp}, {30'd0, RESP_OK});
    axil_write(CONTROL, (32'h1 << IRQ_EN) | (32'h1 << START), 4'hf, axil_resp);
    check_eq32("transfer0 start resp", {30'd0, axil_resp}, {30'd0, RESP_OK});

    wait_dma_done(status_data);
    check_eq32("transfer0 STATUS busy", {31'd0, status_data[BUSY]}, 32'd0);
    check_eq32("transfer0 STATUS done", {31'd0, status_data[DONE]}, 32'd1);
    check_eq32("transfer0 STATUS err",  {31'd0, status_data[ERR]},  32'd0);
    check_eq32("transfer0 dma_irq", {31'd0, dma_irq}, 32'd1);

    check_eq32("transfer0 DST word0", mem[32'h0000_0200 >> 2], 32'h1111_0000);
    check_eq32("transfer0 DST word1", mem[32'h0000_0204 >> 2], 32'h2222_0001);
    check_eq32("transfer0 DST word2", mem[32'h0000_0208 >> 2], 32'h3333_0002);
    check_eq32("transfer0 DST word3", mem[32'h0000_020c >> 2], 32'h4444_0003);

    axil_write(CONTROL, (32'h1 << IRQ_EN) | (32'h1 << CLEAR_DONE), 4'hf, axil_resp);
    check_eq32("transfer0 clear DONE resp", {30'd0, axil_resp}, {30'd0, RESP_OK});
    repeat(2) @(posedge clk);
    axil_read(STATUS, status_data, axil_resp);
    check_eq32("transfer0 clear DONE status", {31'd0, status_data[DONE]}, 32'd0);
    axil_read(CONTROL, control_data, axil_resp);
    check_eq32("transfer0 CONTROL keeps IRQ_EN", control_data, 32'h0000_0002);
    check_eq32("transfer0 irq after clear", {31'd0, dma_irq}, 32'd0);

    axil_write(SRC_ADDR, 32'h0000_0300, 4'hf, axil_resp);
    check_eq32("transfer1 write SRC resp", {30'd0, axil_resp}, {30'd0, RESP_OK});
    axil_write(DST_ADDR, 32'h0000_0400, 4'hf, axil_resp);
    check_eq32("transfer1 write DST resp", {30'd0, axil_resp}, {30'd0, RESP_OK});
    axil_write(BYTES_LEN, 32'd32, 4'hf, axil_resp);
    check_eq32("transfer1 write BYTES_LEN resp", {30'd0, axil_resp}, {30'd0, RESP_OK});
    axil_write(CONTROL, (32'h1 << IRQ_EN) | (32'h1 << START), 4'hf, axil_resp);
    check_eq32("transfer1 start resp", {30'd0, axil_resp}, {30'd0, RESP_OK});

    wait_dma_done(status_data);
    check_eq32("transfer1 STATUS busy", {31'd0, status_data[BUSY]}, 32'd0);
    check_eq32("transfer1 STATUS done", {31'd0, status_data[DONE]}, 32'd1);
    check_eq32("transfer1 STATUS err",  {31'd0, status_data[ERR]},  32'd0);
    check_eq32("transfer1 dma_irq", {31'd0, dma_irq}, 32'd1);

    check_eq32("transfer1 DST word0", mem[32'h0000_0400 >> 2], 32'haaaa_1000);
    check_eq32("transfer1 DST word1", mem[32'h0000_0404 >> 2], 32'hbbbb_1001);
    check_eq32("transfer1 DST word2", mem[32'h0000_0408 >> 2], 32'hcccc_1002);
    check_eq32("transfer1 DST word3", mem[32'h0000_040c >> 2], 32'hdddd_1003);
    check_eq32("transfer1 DST word4", mem[32'h0000_0410 >> 2], 32'heeee_1004);
    check_eq32("transfer1 DST word5", mem[32'h0000_0414 >> 2], 32'hffff_1005);
    check_eq32("transfer1 DST word6", mem[32'h0000_0418 >> 2], 32'h1234_1006);
    check_eq32("transfer1 DST word7", mem[32'h0000_041c >> 2], 32'h5678_1007);

    check_eq32("total AR count", ar_count, 32'd2);
    check_eq32("total AW count", aw_count, 32'd2);
    check_eq32("total R beat count", r_count, 32'd12);
    check_eq32("total W beat count", w_count, 32'd12);
    check_eq32("total B count", b_count, 32'd2);

    axil_write(CONTROL, (32'h1 << CLEAR_DONE), 4'hf, axil_resp);
    check_eq32("final clear CONTROL resp", {30'd0, axil_resp}, {30'd0, RESP_OK});
    repeat(2) @(posedge clk);
    axil_read(STATUS, status_data, axil_resp);
    check_eq32("final STATUS done clear", {31'd0, status_data[DONE]}, 32'd0);
    check_eq32("final STATUS err clear",  {31'd0, status_data[ERR]},  32'd0);
    axil_read(CONTROL, control_data, axil_resp);
    check_eq32("final CONTROL clear", control_data, 32'h0000_0000);
    check_eq32("final dma_irq clear", {31'd0, dma_irq}, 32'd0);

    if(error_count == 0)
        $display("==== DMA two-transfer test PASSED ====");
    else
        $display("==== DMA two-transfer test FAILED: %0d error(s) ====", error_count);

    $finish;
end

endmodule