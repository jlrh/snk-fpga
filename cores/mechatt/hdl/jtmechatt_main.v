`timescale 1ns/1ps
module jtmechatt_main(
    input             rst,
    input             clk,
    input             LVBL,
    input             dip_pause,
    output            main_cs,
    output     [18:1] main_addr,
    input      [15:0] main_data,
    input             main_ok,
    input      [15:0] in0, dsw,
    input      [ 7:0] gun_x1, gun_y1, gun_x2, gun_y2,
    output reg [ 1:0] recoil,
    output reg [ 1:0] coin_cnt,
    output reg [ 7:0] snd_latch,
    output reg        snd_latch_we,
    input      [ 7:0] snd_reply,
    input      [11:1] tx_vaddr,   output [15:0] tx_vq,
    input      [13:1] pf1_vaddr,  output [15:0] pf1_vq,
    input      [13:1] pf2_vaddr,  output [15:0] pf2_vq,
    input      [11:1] pal_vaddr,  output [15:0] pal_vq,
    input      [11:1] spr1_vaddr, output [15:0] spr1_vq,
    output reg [15:0] scr1x, scr1y, scr2x, scr2y,
    output reg        txpage
);

wire [23:1] A;
wire [15:0] cpu_dout;
reg  [15:0] cpu_din;
wire [ 1:0] dsn;
wire        ASn, RnW, DTACKn, cpu_cen, cpu_cenb;
wire [ 2:0] FC;
reg  [ 2:0] IPLn;

wire as      = ~ASn;
wire inta    = as & (&FC);
wire VPAn    = ~inta;
wire [1:0] bwe = (as & ~RnW & ~inta) ? ~dsn : 2'b00;

wire [7:0] seg = A[23:16];
wire rom_cs   = as & ~inta & (seg <= 8'h06);
wire wram_cs  = as & ~inta & (seg == 8'h07);
wire tx_cs    = as & ~inta & (seg == 8'h09) & (A[15:12] == 4'h0);
wire page_cs  = as & ~inta & (seg == 8'h09) & (A[15:1] == 15'h4000);
wire spr_cs   = as & ~inta & (seg == 8'h0A) & (A[15:12] == 4'h0);
wire pf1_cs   = as & ~inta & (seg == 8'h0B) & (A[15:14] == 2'b00);
wire scr1_cs  = as & ~inta & (seg == 8'h0B) & (A[15:2] == 14'h2000);
wire pf2_cs   = as & ~inta & (seg == 8'h0C) & (A[15:14] == 2'b00);
wire scr2_cs  = as & ~inta & (seg == 8'h0C) & (A[15:2] == 14'h2000);
wire pal_cs   = as & ~inta & (seg == 8'h0D) & (A[15:11] == 5'd0);
wire in_cs    = as & ~inta & (seg == 8'h0E) & (A[15:3] == 13'd0);
wire out_cs   = as & ~inta & (seg == 8'h0E) & (A[15:2] == 14'h1000);
wire lat_cs   = as & ~inta & (seg == 8'h0E) & (A[15:1] == 15'h4000);

assign main_cs   = rom_cs;
assign main_addr = A[18:1];

wire [15:0] wram_q, tx_q, spr_q, pf1_q, pf2_q, pal_q;
jtframe_ram16 #(.AW(15)) u_wram(.clk(clk), .data(cpu_dout), .addr(A[15:1]), .we(wram_cs ? bwe : 2'b00), .q(wram_q));
jtframe_dual_ram16 #(.AW(11)) u_tx(
    .clk0(clk), .data0(cpu_dout), .addr0(A[11:1]), .we0(tx_cs ? bwe : 2'b00), .q0(tx_q),
    .clk1(clk), .data1(16'd0), .addr1(tx_vaddr), .we1(2'b00), .q1(tx_vq));
jtframe_dual_ram16 #(.AW(11)) u_spr(
    .clk0(clk), .data0(cpu_dout), .addr0(A[11:1]), .we0(spr_cs ? bwe : 2'b00), .q0(spr_q),
    .clk1(clk), .data1(16'd0), .addr1(spr1_vaddr), .we1(2'b00), .q1(spr1_vq));
jtframe_dual_ram16 #(.AW(13)) u_pf1(
    .clk0(clk), .data0(cpu_dout), .addr0(A[13:1]), .we0(pf1_cs ? bwe : 2'b00), .q0(pf1_q),
    .clk1(clk), .data1(16'd0), .addr1(pf1_vaddr), .we1(2'b00), .q1(pf1_vq));
jtframe_dual_ram16 #(.AW(13)) u_pf2(
    .clk0(clk), .data0(cpu_dout), .addr0(A[13:1]), .we0(pf2_cs ? bwe : 2'b00), .q0(pf2_q),
    .clk1(clk), .data1(16'd0), .addr1(pf2_vaddr), .we1(2'b00), .q1(pf2_vq));
jtframe_dual_ram16 #(.AW(10)) u_pal(
    .clk0(clk), .data0(cpu_dout), .addr0(A[10:1]), .we0(pal_cs ? bwe : 2'b00), .q0(pal_q),
    .clk1(clk), .data1(16'd0), .addr1(pal_vaddr[10:1]), .we1(2'b00), .q1(pal_vq));

function [15:0] gun( input [7:0] x, input [7:0] y );
    reg [8:0] xs;
    begin
        xs  = {1'b0, x} + 9'h18;
        gun = { (y > 8'hEF) ? 8'hEF : y, xs[8] ? 8'hFF : xs[7:0] };
    end
endfunction

reg snd_we_l;
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        scr1x <= 0; scr1y <= 0; scr2x <= 0; scr2y <= 0; txpage <= 0; recoil <= 0; coin_cnt <= 0;
        snd_latch <= 0; snd_latch_we <= 0; snd_we_l <= 0;
    end else begin
        snd_latch_we <= 0;
        if( |bwe ) begin
            if( scr1_cs ) begin if( A[1] ) scr1y <= cpu_dout; else scr1x <= cpu_dout; end
            if( scr2_cs ) begin if( A[1] ) scr2y <= cpu_dout; else scr2x <= cpu_dout; end
            if( page_cs ) txpage <= cpu_dout[0];
            if( out_cs ) begin
                if( !A[1] ) coin_cnt <= cpu_dout[1:0];
                else        recoil   <= cpu_dout[1:0];
            end
        end

        snd_we_l <= lat_cs & ~RnW & ~dsn[0];
        if( lat_cs & ~RnW & ~dsn[0] & ~snd_we_l ) begin
            snd_latch    <= cpu_dout[7:0];
            snd_latch_we <= 1;
        end
    end
end

always @* begin
    cpu_din = 16'h0000;
    if( rom_cs  ) cpu_din = main_data;
    if( wram_cs ) cpu_din = wram_q;
    if( tx_cs   ) cpu_din = tx_q;
    if( spr_cs  ) cpu_din = spr_q;
    if( pf1_cs  ) cpu_din = pf1_q;
    if( pf2_cs  ) cpu_din = pf2_q;
    if( pal_cs  ) cpu_din = pal_q;
    if( in_cs   ) case( A[2:1] )
        2'd0: cpu_din = in0;
        2'd1: cpu_din = dsw;
        2'd2: cpu_din = gun( gun_x1, gun_y1 );
        2'd3: cpu_din = gun( gun_x2, gun_y2 );
    endcase
    if( lat_cs  ) cpu_din = { 8'h00, snd_reply };
end

reg irq4, lvbl_l;
always @(posedge clk, posedge rst) begin
    if( rst ) begin irq4 <= 0; lvbl_l <= 1; end
    else begin
        lvbl_l <= LVBL;
        if( lvbl_l & ~LVBL ) irq4 <= 1;
        else if( inta && A[3:1] == 3'd4 ) irq4 <= 0;
    end
end
always @(posedge clk) IPLn <= irq4 ? 3'b011 : 3'b111;

`ifdef SIMULATION
integer frame_cnt = 0;
reg     io_l = 0;
wire    io_acc = as & ~inta & (page_cs | in_cs | out_cs | lat_cs);
always @(posedge clk) begin
    if( lvbl_l & ~LVBL ) frame_cnt <= frame_cnt + 1;
    io_l <= io_acc & ~DTACKn;
    if( io_acc & ~DTACKn & ~io_l )
        $display("IOTRACE cuadro=%0d %s %06x dato=%04x", frame_cnt, RnW ? "R" : "W", {A,1'b0}, RnW ? cpu_din : cpu_dout);
end
`endif

jtframe_68kdtack_cen #(.W(8)) u_dtack(
    .rst(rst), .clk(clk), .cpu_cen(cpu_cen), .cpu_cenb(cpu_cenb),
    .bus_cs(rom_cs), .bus_busy(rom_cs & ~main_ok), .bus_legit(1'b0), .bus_ack(1'b0),
    .ASn(ASn), .DSn(dsn), .num(7'd1), .den(8'd4),
    .DTACKn(DTACKn), .wait2(1'b0), .wait3(1'b0), .fave(), .fworst() );

jtframe_m68k u_cpu(
    .clk(clk), .rst(rst), .RESETn(), .cpu_cen(cpu_cen), .cpu_cenb(cpu_cenb),
    .eab(A), .iEdb(cpu_din), .oEdb(cpu_dout), .eRWn(RnW), .LDSn(dsn[0]), .UDSn(dsn[1]), .ASn(ASn),
    .VPAn(VPAn), .FC(FC), .BERRn(1'b1), .HALTn(dip_pause), .BRn(1'b1), .BGACKn(1'b1), .BGn(),
    .DTACKn(DTACKn), .IPLn(IPLn) );

endmodule
