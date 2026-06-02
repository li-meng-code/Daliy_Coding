`timescale 1ns/1ps

module tb_fifo;

parameter WIDTH = 32;
parameter DEPTH = 8;

reg                  clk;
reg                  rst_n;
reg  [WIDTH-1:0]     data_in;
reg                  wr_en;
wire                 full;
wire [WIDTH-1:0]     data_out;
reg                  rd_en;
wire                 empty;

reg [WIDTH-1:0] model_q[$];

integer i;
integer seed;

fifo #(
    .WIDTH(WIDTH),
    .DEPTH(DEPTH)
) u_fifo (
    .clk      (clk),
    .rst_n    (rst_n),
    .data_in  (data_in),
    .wr_en    (wr_en),
    .full     (full),
    .data_out (data_out),
    .rd_en    (rd_en),
    .empty    (empty)
);

always #5 clk = ~clk;

initial begin
    $fsdbDumpfile("tb_fifo.fsdb");
    $fsdbDumpvars(0, tb_fifo);
    $fsdbDumpMDA();
end

task check_flags;
    begin
        #1;
        if (empty !== (model_q.size() == 0)) begin
            $display("ERROR: empty mismatch, dut=%0b model_size=%0d time=%0t",
                     empty, model_q.size(), $time);
            $fatal;
        end

        if (full !== (model_q.size() == DEPTH)) begin
            $display("ERROR: full mismatch, dut=%0b model_size=%0d time=%0t",
                     full, model_q.size(), $time);
            $fatal;
        end
    end
endtask

task one_cycle;
    input              do_wr;
    input              do_rd;
    input [WIDTH-1:0]  wdata;

    reg                wr_accept;
    reg                rd_accept;
    reg [WIDTH-1:0]    expected_rdata;

    begin
        @(negedge clk);

        wr_accept = do_wr && !full;
        rd_accept = do_rd && !empty;

        if (rd_accept) begin
            expected_rdata = model_q[0];
        end

        wr_en   = do_wr;
        rd_en   = do_rd;
        data_in = wdata;

        @(posedge clk);
        #1;

        if (rd_accept) begin
            if (data_out !== expected_rdata) begin
                $display("ERROR: read mismatch, expected=%h actual=%h time=%0t",
                         expected_rdata, data_out, $time);
                $fatal;
            end
            model_q.pop_front();
        end

        if (wr_accept) begin
            model_q.push_back(wdata);
        end

        wr_en   = 1'b0;
        rd_en   = 1'b0;
        data_in = {WIDTH{1'b0}};

        check_flags();
    end
endtask

task reset_fifo;
    begin
        clk     = 1'b0;
        rst_n   = 1'b0;
        wr_en   = 1'b0;
        rd_en   = 1'b0;
        data_in = {WIDTH{1'b0}};
        model_q.delete();

        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        check_flags();

        if (empty !== 1'b1 || full !== 1'b0) begin
            $display("ERROR: reset state wrong");
            $fatal;
        end

        $display("PASS: reset check");
    end
endtask

initial begin
    seed = 32'h1234_5678;

    reset_fifo();

    $display("===== Case 1: single write and single read =====");
    one_cycle(1'b1, 1'b0, 32'h0000_0001);
    one_cycle(1'b0, 1'b1, 32'h0000_0000);

    $display("===== Case 2: read when empty =====");
    one_cycle(1'b0, 1'b1, 32'h0000_0000);

    $display("===== Case 3: write until full =====");
    for (i = 0; i < DEPTH; i = i + 1) begin
        one_cycle(1'b1, 1'b0, 32'h1000_0000 + i);
    end

    if (full !== 1'b1) begin
        $display("ERROR: FIFO should be full");
        $fatal;
    end
    $display("PASS: full asserted");

    $display("===== Case 4: write when full =====");
    one_cycle(1'b1, 1'b0, 32'hDEAD_BEEF);

    if (model_q.size() != DEPTH) begin
        $display("ERROR: overflow write changed model size");
        $fatal;
    end
    $display("PASS: overflow write blocked");

    $display("===== Case 5: read until empty =====");
    for (i = 0; i < DEPTH; i = i + 1) begin
        one_cycle(1'b0, 1'b1, 32'h0000_0000);
    end

    if (empty !== 1'b1) begin
        $display("ERROR: FIFO should be empty");
        $fatal;
    end
    $display("PASS: empty asserted");

    $display("===== Case 6: pointer wrap around =====");
    for (i = 0; i < DEPTH; i = i + 1) begin
        one_cycle(1'b1, 1'b0, 32'h2000_0000 + i);
    end

    for (i = 0; i < 4; i = i + 1) begin
        one_cycle(1'b0, 1'b1, 32'h0000_0000);
    end

    for (i = 0; i < 4; i = i + 1) begin
        one_cycle(1'b1, 1'b0, 32'h3000_0000 + i);
    end

    while (model_q.size() != 0) begin
        one_cycle(1'b0, 1'b1, 32'h0000_0000);
    end
    $display("PASS: pointer wrap around");

    $display("===== Case 7: simultaneous read and write =====");
    for (i = 0; i < 4; i = i + 1) begin
        one_cycle(1'b1, 1'b0, 32'h4000_0000 + i);
    end

    for (i = 0; i < 8; i = i + 1) begin
        one_cycle(1'b1, 1'b1, 32'h5000_0000 + i);
    end

    while (model_q.size() != 0) begin
        one_cycle(1'b0, 1'b1, 32'h0000_0000);
    end
    $display("PASS: simultaneous read/write");

    $display("===== Case 8: random stress test =====");
    for (i = 0; i < 200; i = i + 1) begin
        one_cycle($random(seed), $random(seed), 32'h6000_0000 + i);
    end

    while (model_q.size() != 0) begin
        one_cycle(1'b0, 1'b1, 32'h0000_0000);
    end

    $display("======================================");
    $display("FIFO ALL TESTS PASSED");
    $display("======================================");

    #20;
    $finish;
end

endmodule