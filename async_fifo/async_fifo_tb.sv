`timescale 1ns/1ps

module tb_async_fifo;

parameter DATA_WIDTH = 32;
parameter DEPTH      = 8;

reg                   wr_clk;
reg                   wr_rst_n;
reg  [DATA_WIDTH-1:0] wr_data;
reg                   wr_en;
wire                  full;

reg                   rd_clk;
reg                   rd_rst_n;
wire [DATA_WIDTH-1:0] rd_data;
reg                   rd_en;
wire                  empty;

reg [DATA_WIDTH-1:0] model_q[$];
reg [DATA_WIDTH-1:0] expected_data;

integer seed;
integer wr_accept_cnt;
integer rd_accept_cnt;
integer error_cnt;

integer real_fifo_count;

wire false_full_now;
wire false_empty_now;

reg false_full_seen;
reg false_empty_seen;

async_fifo #(
    .DATA_WIDTH(DATA_WIDTH),
    .DEPTH     (DEPTH)
) u_async_fifo (
    .wr_clk   (wr_clk),
    .wr_rst_n (wr_rst_n),
    .wr_data  (wr_data),
    .wr_en    (wr_en),
    .full     (full),

    .rd_clk   (rd_clk),
    .rd_rst_n (rd_rst_n),
    .rd_data  (rd_data),
    .rd_en    (rd_en),
    .empty    (empty)
);

// ??????
initial begin
    wr_clk = 1'b0;
    forever #5 wr_clk = ~wr_clk;      // 10ns period
end

// ?????????????
initial begin
    rd_clk = 1'b0;
    #3;
    forever #11 rd_clk = ~rd_clk;     // 22ns period
end

initial begin
    $fsdbDumpfile("tb_async_fifo.fsdb");
    $fsdbDumpvars(0, tb_async_fifo);
    $fsdbDumpMDA();
end

always @(*) begin
    real_fifo_count = wr_accept_cnt - rd_accept_cnt;
end

// ???????????? DEPTH?? full ??? 1
assign false_full_now = full && (real_fifo_count < DEPTH);

// ???????????? 0?? empty ??? 1
assign false_empty_now = empty && (real_fifo_count > 0);

always @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) begin
        false_full_seen <= 1'b0;
    end
    else if (false_full_now) begin
        false_full_seen <= 1'b1;
        $display("[%0t] FALSE FULL observed: full=1, real_count=%0d",
                 $time, real_fifo_count);
    end
end

always @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) begin
        false_empty_seen <= 1'b0;
    end
    else if (false_empty_now) begin
        false_empty_seen <= 1'b1;
        $display("[%0t] FALSE EMPTY observed: empty=1, real_count=%0d",
                 $time, real_fifo_count);
    end
end

// ??????
always @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) begin
    end
    else if (wr_en && !full) begin
        model_q.push_back(wr_data);
        wr_accept_cnt = wr_accept_cnt + 1;

        $display("[%0t] WRITE accepted: data=%h, real_count=%0d",
                 $time, wr_data, real_fifo_count + 1);
    end
end

// ??????
always @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) begin
    end
    else if (rd_en && !empty) begin
        if (model_q.size() == 0) begin
            $display("[%0t] ERROR: model queue empty, but DUT read accepted", $time);
            error_cnt = error_cnt + 1;
        end
        else begin
            expected_data = model_q.pop_front();

            #1;
            if (rd_data !== expected_data) begin
                $display("[%0t] ERROR: read mismatch, expected=%h, actual=%h",
                         $time, expected_data, rd_data);
                error_cnt = error_cnt + 1;
            end
            else begin
                $display("[%0t] READ accepted: data=%h, real_count=%0d",
                         $time, rd_data, real_fifo_count - 1);
            end
        end

        rd_accept_cnt = rd_accept_cnt + 1;
    end
end

task reset_dut;
    begin
        wr_rst_n = 1'b0;
        rd_rst_n = 1'b0;
        wr_en    = 1'b0;
        rd_en    = 1'b0;
        wr_data  = {DATA_WIDTH{1'b0}};

        seed          = 32'h1234_5678;
        wr_accept_cnt = 0;
        rd_accept_cnt = 0;
        error_cnt     = 0;
        model_q.delete();

        repeat (5) @(posedge wr_clk);
        repeat (5) @(posedge rd_clk);

        wr_rst_n = 1'b1;
        rd_rst_n = 1'b1;

        repeat (5) @(posedge wr_clk);
        repeat (5) @(posedge rd_clk);

        if (full !== 1'b0) begin
            $display("[%0t] ERROR: full should be 0 after reset", $time);
            error_cnt = error_cnt + 1;
        end

        if (empty !== 1'b1) begin
            $display("[%0t] ERROR: empty should be 1 after reset", $time);
            error_cnt = error_cnt + 1;
        end

        $display("[%0t] RESET done", $time);
    end
endtask

task phase1_write_until_full;
    integer write_cnt;
    begin
        write_cnt = 0;
        $display("\n========== PHASE 1: write until full, 8 random data ==========");

        while (write_cnt < DEPTH) begin
            @(negedge wr_clk);
            if (!full) begin
                wr_en   = 1'b1;
                wr_data = $random(seed);
                write_cnt = write_cnt + 1;
            end
            else begin
                wr_en   = 1'b0;
                wr_data = {DATA_WIDTH{1'b0}};
            end
        end

        @(negedge wr_clk);
        wr_en = 1'b0;

        while (full !== 1'b1) begin
            @(posedge wr_clk);
        end

        $display("[%0t] PHASE 1 done: full asserted", $time);
    end
endtask

task phase2_read_until_empty;
    begin
        $display("\n========== PHASE 2: read until empty ==========");

        // ??????????? full ?????????????????
        while (rd_accept_cnt < wr_accept_cnt) begin
            @(negedge rd_clk);
            if (!empty) begin
                rd_en = 1'b1;
            end
            else begin
                rd_en = 1'b0;
            end
        end

        @(negedge rd_clk);
        rd_en = 1'b0;

        while (empty !== 1'b1) begin
            @(posedge rd_clk);
        end

        $display("[%0t] PHASE 2 done: empty asserted", $time);
    end
endtask

task phase3_write_only_4;
    integer write_cnt;
    begin
        write_cnt = 0;
        $display("\n========== PHASE 3: only write 4 data ==========");

        // ??????????? empty ?????????????????
        while (write_cnt < 4) begin
            @(negedge wr_clk);
            if (!full) begin
                wr_en   = 1'b1;
                wr_data = 32'h4000_0000 + write_cnt;
                write_cnt = write_cnt + 1;
            end
            else begin
                wr_en   = 1'b0;
                wr_data = {DATA_WIDTH{1'b0}};
            end
        end

        @(negedge wr_clk);
        wr_en = 1'b0;

        // ????????????????? false_empty_now
        repeat (8) @(posedge rd_clk);

        $display("[%0t] PHASE 3 done: wrote 4 data", $time);
    end
endtask

task phase4_simultaneous_read_write;
    integer k;
    begin
        $display("\n========== PHASE 4: simultaneous read/write ==========");

        fork
            begin
                for (k = 0; k < 12; k = k + 1) begin
                    @(negedge wr_clk);
                    if (!full) begin
                        wr_en   = 1'b1;
                        wr_data = 32'h8000_0000 + k;
                    end
                    else begin
                        wr_en   = 1'b0;
                        wr_data = {DATA_WIDTH{1'b0}};
                    end
                end

                @(negedge wr_clk);
                wr_en = 1'b0;
            end

            begin
                for (k = 0; k < 12; k = k + 1) begin
                    @(negedge rd_clk);
                    if (!empty) begin
                        rd_en = 1'b1;
                    end
                    else begin
                        rd_en = 1'b0;
                    end
                end

                @(negedge rd_clk);
                rd_en = 1'b0;
            end
        join

        repeat (10) @(posedge wr_clk);
        repeat (10) @(posedge rd_clk);

        $display("[%0t] PHASE 4 done", $time);
    end
endtask

initial begin
    reset_dut();

    phase1_write_until_full();
    phase2_read_until_empty();
    phase3_write_only_4();
    phase4_simultaneous_read_write();

    repeat (20) @(posedge wr_clk);
    repeat (20) @(posedge rd_clk);

    $display("\n========== SUMMARY ==========");
    $display("wr_accept_cnt    = %0d", wr_accept_cnt);
    $display("rd_accept_cnt    = %0d", rd_accept_cnt);
    $display("real_fifo_count  = %0d", real_fifo_count);
    $display("false_full_seen  = %0b", false_full_seen);
    $display("false_empty_seen = %0b", false_empty_seen);
    $display("error_cnt        = %0d", error_cnt);

    if (error_cnt == 0) begin
        $display("ASYNC FIFO TEST PASSED");
    end
    else begin
        $display("ASYNC FIFO TEST FAILED");
    end

    #100;
    $finish;
end

initial begin
    #200000;
    $display("ERROR: simulation timeout");
    $finish;
end

endmodule