`timescale 1ns/1ps

module tb_lite_slave;

localparam ADDR_WIDTH = 32;
localparam DATA_WIDTH = 32;
localparam ID_WIDTH   = 4;

localparam [ADDR_WIDTH-1:0] SRC_ADDR  = 32'h0000_0000;
localparam [ADDR_WIDTH-1:0] DST_ADDR  = 32'h0000_0004;
localparam [ADDR_WIDTH-1:0] BURST_LEN = 32'h0000_0008;
localparam [ADDR_WIDTH-1:0] BYTES_LEN = 32'h0000_000C;
localparam [ADDR_WIDTH-1:0] CONTROL   = 32'h0000_0010;
localparam [ADDR_WIDTH-1:0] STATUS    = 32'h0000_0014;
localparam [ADDR_WIDTH-1:0] BAD_ADDR  = 32'h0000_0020;

localparam [1:0] RESP_OK     = 2'b00;
localparam [1:0] RESP_SLVERR = 2'b10;

reg clk;
reg rst_n;

reg  [ADDR_WIDTH-1:0]   s_axil_awaddr;
reg                     s_axil_awvalid;
wire                    s_axil_awready;

reg  [DATA_WIDTH-1:0]   s_axil_wdata;
reg  [DATA_WIDTH/8-1:0] s_axil_wstrb;
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

integer err_count;

reg [DATA_WIDTH-1:0] read_data;
reg [1:0]            read_resp;
reg [1:0]            write_resp;

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

initial begin
    $fsdbDumpfile("tb_lite_slave.fsdb");
    $fsdbDumpvars(0, tb_lite_slave);
    $fsdbDumpMDA();
end

lite_slave #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ID_WIDTH(ID_WIDTH)
) dut (
    .clk(clk),
    .rst_n(rst_n),

    .s_axil_awaddr(s_axil_awaddr),
    .s_axil_awvalid(s_axil_awvalid),
    .s_axil_awready(s_axil_awready),

    .s_axil_wdata(s_axil_wdata),
    .s_axil_wstrb(s_axil_wstrb),
    .s_axil_wvalid(s_axil_wvalid),
    .s_axil_wready(s_axil_wready),

    .s_axil_bresp(s_axil_bresp),
    .s_axil_bvalid(s_axil_bvalid),
    .s_axil_bready(s_axil_bready),

    .s_axil_araddr(s_axil_araddr),
    .s_axil_arvalid(s_axil_arvalid),
    .s_axil_arready(s_axil_arready),

    .s_axil_rdata(s_axil_rdata),
    .s_axil_rresp(s_axil_rresp),
    .s_axil_rvalid(s_axil_rvalid),
    .s_axil_rready(s_axil_rready)
);

task init_bus;
begin
    s_axil_awaddr  = {ADDR_WIDTH{1'b0}};
    s_axil_awvalid = 1'b0;
    s_axil_wdata   = {DATA_WIDTH{1'b0}};
    s_axil_wstrb   = {DATA_WIDTH/8{1'b0}};
    s_axil_wvalid  = 1'b0;
    s_axil_bready  = 1'b0;
    s_axil_araddr  = {ADDR_WIDTH{1'b0}};
    s_axil_arvalid = 1'b0;
    s_axil_rready  = 1'b0;
end
endtask

task check_equal;
    input [1023:0] name;
    input [31:0]   got;
    input [31:0]   exp;
begin
    if (got !== exp) begin
        err_count = err_count + 1;
        $display("[FAIL] %0s got=0x%08h exp=0x%08h time=%0t", name, got, exp, $time);
    end else begin
        $display("[PASS] %0s got=0x%08h", name, got);
    end
end
endtask

task check_resp;
    input [1023:0] name;
    input [1:0]    got;
    input [1:0]    exp;
begin
    if (got !== exp) begin
        err_count = err_count + 1;
        $display("[FAIL] %0s resp=%b exp=%b time=%0t", name, got, exp, $time);
    end else begin
        $display("[PASS] %0s resp=%b", name, got);
    end
end
endtask

// AW and W are driven at the same time.
task axil_write_same_cycle;
    input [ADDR_WIDTH-1:0]   addr;
    input [DATA_WIDTH-1:0]   data;
    input [DATA_WIDTH/8-1:0] strb;
    output [1:0]             resp;
begin
    @(negedge clk);
    s_axil_awaddr  = addr;
    s_axil_awvalid = 1'b1;
    s_axil_wdata   = data;
    s_axil_wstrb   = strb;
    s_axil_wvalid  = 1'b1;
    s_axil_bready  = 1'b0;

    while (!(s_axil_awready && s_axil_wready)) begin
        @(posedge clk);
    end

    @(negedge clk);
    s_axil_awvalid = 1'b0;
    s_axil_wvalid  = 1'b0;
    s_axil_bready  = 1'b1;

    while (!s_axil_bvalid) begin
        @(posedge clk);
    end
    resp = s_axil_bresp;

    @(negedge clk);
    s_axil_bready = 1'b0;
end
endtask

// AW arrives before W.
task axil_write_aw_first;
    input [ADDR_WIDTH-1:0]   addr;
    input [DATA_WIDTH-1:0]   data;
    input [DATA_WIDTH/8-1:0] strb;
    output [1:0]             resp;
begin
    @(negedge clk);
    s_axil_awaddr  = addr;
    s_axil_awvalid = 1'b1;
    s_axil_bready  = 1'b0;

    while (!s_axil_awready) begin
        @(posedge clk);
    end

    @(negedge clk);
    s_axil_awvalid = 1'b0;

    repeat (2) @(posedge clk);
    @(negedge clk);
    s_axil_wdata  = data;
    s_axil_wstrb  = strb;
    s_axil_wvalid = 1'b1;

    while (!s_axil_wready) begin
        @(posedge clk);
    end

    @(negedge clk);
    s_axil_wvalid = 1'b0;
    s_axil_bready = 1'b1;

    while (!s_axil_bvalid) begin
        @(posedge clk);
    end
    resp = s_axil_bresp;

    @(negedge clk);
    s_axil_bready = 1'b0;
end
endtask

// W arrives before AW.
task axil_write_w_first;
    input [ADDR_WIDTH-1:0]   addr;
    input [DATA_WIDTH-1:0]   data;
    input [DATA_WIDTH/8-1:0] strb;
    output [1:0]             resp;
begin
    @(negedge clk);
    s_axil_wdata  = data;
    s_axil_wstrb  = strb;
    s_axil_wvalid = 1'b1;
    s_axil_bready = 1'b0;

    while (!s_axil_wready) begin
        @(posedge clk);
    end

    @(negedge clk);
    s_axil_wvalid = 1'b0;

    repeat (2) @(posedge clk);
    @(negedge clk);
    s_axil_awaddr  = addr;
    s_axil_awvalid = 1'b1;

    while (!s_axil_awready) begin
        @(posedge clk);
    end

    @(negedge clk);
    s_axil_awvalid = 1'b0;
    s_axil_bready  = 1'b1;

    while (!s_axil_bvalid) begin
        @(posedge clk);
    end
    resp = s_axil_bresp;

    @(negedge clk);
    s_axil_bready = 1'b0;
end
endtask

task axil_read;
    input  [ADDR_WIDTH-1:0] addr;
    output [DATA_WIDTH-1:0] data;
    output [1:0]            resp;
begin
    @(negedge clk);
    s_axil_araddr  = addr;
    s_axil_arvalid = 1'b1;
    s_axil_rready  = 1'b0;

    while (!s_axil_arready) begin
        @(posedge clk);
    end

    @(negedge clk);
    s_axil_arvalid = 1'b0;
    s_axil_rready  = 1'b1;

    while (!s_axil_rvalid) begin
        @(posedge clk);
    end
    data = s_axil_rdata;
    resp = s_axil_rresp;

    @(negedge clk);
    s_axil_rready = 1'b0;
end
endtask

initial begin
    $display("==== dma_axi AXI-Lite register test start ====");
    err_count = 0;
    rst_n = 1'b0;
    init_bus();

    repeat (5) @(posedge clk);
    rst_n <= 1'b1;
    repeat (2) @(posedge clk);

    // Reset/default read checks.
    axil_read(SRC_ADDR, read_data, read_resp);
    check_resp("read SRC reset resp", read_resp, RESP_OK);
    check_equal("read SRC reset data", read_data, 32'h0000_0000);

    axil_read(CONTROL, read_data, read_resp);
    check_resp("read CONTROL reset resp", read_resp, RESP_OK);
    check_equal("read CONTROL reset data", read_data, 32'h0000_0000);

    // AW/W same-cycle write.
    axil_write_same_cycle(SRC_ADDR, 32'h1122_3344, 4'b1111, write_resp);
    check_resp("write SRC same-cycle", write_resp, RESP_OK);
    axil_read(SRC_ADDR, read_data, read_resp);
    check_resp("read SRC after same-cycle write", read_resp, RESP_OK);
    check_equal("SRC full write", read_data, 32'h1122_3344);

    // AW first write.
    axil_write_aw_first(DST_ADDR, 32'h5566_7788, 4'b1111, write_resp);
    check_resp("write DST aw-first", write_resp, RESP_OK);
    axil_read(DST_ADDR, read_data, read_resp);
    check_resp("read DST after aw-first write", read_resp, RESP_OK);
    check_equal("DST full write", read_data, 32'h5566_7788);

    // W first write.
    axil_write_w_first(BYTES_LEN, 32'h0000_0400, 4'b1111, write_resp);
    check_resp("write BYTES_LEN w-first", write_resp, RESP_OK);
    axil_read(BYTES_LEN, read_data, read_resp);
    check_resp("read BYTES_LEN after w-first write", read_resp, RESP_OK);
    check_equal("BYTES_LEN full write", read_data, 32'h0000_0400);

    // Byte strobe check: only byte lane 0 updates.
    axil_write_same_cycle(SRC_ADDR, 32'hAABB_CCDD, 4'b0001, write_resp);
    check_resp("partial byte write SRC", write_resp, RESP_OK);
    axil_read(SRC_ADDR, read_data, read_resp);
    check_resp("read SRC after partial write", read_resp, RESP_OK);
    check_equal("SRC byte lane0 partial write", read_data, 32'h1122_33DD);

    // Mixed byte strobe check: byte lanes 3 and 1 update.
    axil_write_same_cycle(DST_ADDR, 32'hAABB_CCDD, 4'b1010, write_resp);
    check_resp("partial byte write DST", write_resp, RESP_OK);
    axil_read(DST_ADDR, read_data, read_resp);
    check_resp("read DST after partial write", read_resp, RESP_OK);
    check_equal("DST byte lane3/1 partial write", read_data, 32'hAA66_CC88);

    // Other config registers.
    axil_write_same_cycle(BURST_LEN, 32'h0000_000F, 4'b1111, write_resp);
    check_resp("write BURST_LEN", write_resp, RESP_OK);
    axil_read(BURST_LEN, read_data, read_resp);
    check_equal("BURST_LEN readback", read_data, 32'h0000_000F);

    axil_write_same_cycle(CONTROL, 32'h0000_0003, 4'b1111, write_resp);
    check_resp("write CONTROL", write_resp, RESP_OK);
    axil_read(CONTROL, read_data, read_resp);
    check_equal("CONTROL readback", read_data, 32'h0000_0003);

    // Invalid address response checks.
    axil_write_same_cycle(BAD_ADDR, 32'hDEAD_BEEF, 4'b1111, write_resp);
    check_resp("write invalid addr", write_resp, RESP_SLVERR);

    axil_read(BAD_ADDR, read_data, read_resp);
    check_resp("read invalid addr", read_resp, RESP_SLVERR);
    check_equal("read invalid addr data", read_data, 32'h0000_0000);

    if (err_count == 0) begin
        $display("==== ALL AXI-Lite register tests PASSED ====");
    end else begin
        $display("==== AXI-Lite register tests FAILED: %0d error(s) ====", err_count);
    end

    #20;
    $finish;
end

endmodule
