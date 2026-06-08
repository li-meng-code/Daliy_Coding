`timescale 1ns/1ps
package dma_pkg;

    localparam integer DMA_DEFAULT_ADDR_WIDTH = 32;
    localparam integer DMA_DEFAULT_DATA_WIDTH = 32;
    localparam integer DMA_DEFAULT_ID_WIDTH   = 4;

    localparam [7:0] DMA_REG_SRC_ADDR  = 8'h00;
    localparam [7:0] DMA_REG_DST_ADDR  = 8'h04;
    localparam [7:0] DMA_REG_BURST_LEN = 8'h08;
    localparam [7:0] DMA_REG_BYTES_LEN = 8'h0c;
    localparam [7:0] DMA_REG_CONTROL   = 8'h10;
    localparam [7:0] DMA_REG_STATUS    = 8'h14;

    localparam integer DMA_CTRL_START      = 0;
    localparam integer DMA_CTRL_IRQ_EN     = 1;
    localparam integer DMA_CTRL_CLEAR_DONE = 2;
    localparam integer DMA_CTRL_CLEAR_ERR  = 3;

    localparam integer DMA_STATUS_BUSY = 0;
    localparam integer DMA_STATUS_DONE = 1;
    localparam integer DMA_STATUS_ERR  = 2;

    localparam [1:0] DMA_RESP_OK     = 2'b00;
    localparam [1:0] DMA_RESP_SLVERR = 2'b10;

endpackage
