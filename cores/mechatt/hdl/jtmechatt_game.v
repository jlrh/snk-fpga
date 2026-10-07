`timescale 1ns/1ps
module jtmechatt_game(
    `include "jtframe_game_ports.inc"
);

wire [15:0] in0 = { 1'b1, joystick2[5], joystick2[4], cab_1p[1], 1'b1, joystick1[5], joystick1[4], cab_1p[0],
                    2'b11, coin[3], coin[2], 1'b1, service, coin[1], coin[0] };
wire [15:0] dsw = { dipsw[15] & dip_test, dipsw[14:0] };

function [7:0] gunx( input [8:0] x );
    gunx = x[8] ? 8'hFF : x[7:0];
endfunction
function [7:0] guny( input [8:0] y );
    reg [18:0] m;
    begin
        m    = y * 10'd585;
        guny = m[18:17] != 0 ? 8'hFF : m[16:9];
    end
endfunction
wire [7:0] gun_x1 = gunx(gun_1p_x), gun_y1 = guny(gun_1p_y);
wire [7:0] gun_x2 = gunx(gun_2p_x), gun_y2 = guny(gun_2p_y);

wire [ 7:0] snd_latch, snd_reply;
wire        snd_latch_we;
wire [ 1:0] recoil, coin_cnt;
wire [11:1] tx_vaddr, pal_vaddr, spr1_vaddr, spr2_vaddr;
wire [13:1] pf1_vaddr, pf2_vaddr;
wire [15:0] tx_vq, pf1_vq, pf2_vq, pal_vq, spr1_vq;
wire [15:0] scr1x, scr1y, scr2x, scr2y;
wire        txpage;
wire [ 8:0] vdump, hdump;

assign dip_flip   = 1'b0;
assign debug_view = { 5'd0, txpage, coin_cnt };

jtmechatt_main u_main(
    .rst(rst), .clk(clk), .LVBL(LVBL), .dip_pause(dip_pause),
    .main_cs(main_cs), .main_addr(main_addr), .main_data(main_data), .main_ok(main_ok),
    .in0(in0), .dsw(dsw), .gun_x1(gun_x1), .gun_y1(gun_y1), .gun_x2(gun_x2), .gun_y2(gun_y2),
    .recoil(recoil), .coin_cnt(coin_cnt),
    .snd_latch(snd_latch), .snd_latch_we(snd_latch_we), .snd_reply(snd_reply),
    .tx_vaddr(tx_vaddr), .tx_vq(tx_vq), .pf1_vaddr(pf1_vaddr), .pf1_vq(pf1_vq), .pf2_vaddr(pf2_vaddr), .pf2_vq(pf2_vq),
    .pal_vaddr(pal_vaddr), .pal_vq(pal_vq), .spr1_vaddr(spr1_vaddr), .spr1_vq(spr1_vq),
    .scr1x(scr1x), .scr1y(scr1y), .scr2x(scr2x), .scr2y(scr2y), .txpage(txpage) );

wire signed [15:0] snd_l, snd_r;
jtmechatt_sound u_sound(
    .rst(rst), .clk(clk), .latch_in(snd_latch), .latch_we(snd_latch_we), .reply(snd_reply),
    .snd_cs(snd_cs), .snd_addr(snd_addr), .snd_data(snd_data), .snd_ok(snd_ok),
    .rhy_addr(rhy_addr), .rhy_cs(rhy_cs), .rhy_data(rhy_data), .rhy_ok(rhy_ok),
    .pcmb_addr(pcmb_addr), .pcmb_cs(pcmb_cs), .pcmb_data(pcmb_data), .pcmb_ok(pcmb_ok),
    .snd_left(snd_l), .snd_right(snd_r), .sample(sample) );
jtframe_dcrm #(.SW(16),.SIGNED_INPUT(1)) u_dcl(.rst(rst), .clk(clk), .sample(sample), .din(snd_l), .dout(snd_left));
jtframe_dcrm #(.SW(16),.SIGNED_INPUT(1)) u_dcr(.rst(rst), .clk(clk), .sample(sample), .din(snd_r), .dout(snd_right));

wire [20:2] spr2_addr; wire spr2_cs;
jtbbusters_video #(.NOBJ(1), .PF_COLW(8), .PF_VAW(13), .PALW(10),
    .PF1_BASE(11'd512), .PF2_BASE(11'd768), .OBJ1_BASE(11'd256), .OBJ2_BASE(11'd256)
) u_video(
    .rst(rst), .clk(clk), .pxl2_cen(pxl2_cen), .pxl_cen(pxl_cen),
    .LHBL(LHBL), .LVBL(LVBL), .HS(HS), .VS(VS), .vdump(vdump), .hdump(hdump),
    .red(red), .green(green), .blue(blue), .gfx_en(gfx_en),
    .scr1x(scr1x), .scr1y(scr1y), .scr2x(scr2x), .scr2y(scr2y), .txpage(txpage),
    .tx_vaddr(tx_vaddr), .tx_vq(tx_vq), .pf1_vaddr(pf1_vaddr), .pf1_vq(pf1_vq), .pf2_vaddr(pf2_vaddr), .pf2_vq(pf2_vq),
    .pal_vaddr(pal_vaddr), .pal_vq(pal_vq), .spr1_vaddr(spr1_vaddr), .spr1_vq(spr1_vq),
    .spr2_vaddr(spr2_vaddr), .spr2_vq(16'd0),
    .tx_addr(tx_addr), .tx_cs(tx_cs), .tx_data(tx_data), .tx_ok(tx_ok),
    .bg1_addr(bg1_addr), .bg1_cs(bg1_cs), .bg1_data(bg1_data), .bg1_ok(bg1_ok),
    .bg2_addr(bg2_addr), .bg2_cs(bg2_cs), .bg2_data(bg2_data), .bg2_ok(bg2_ok),
    .spr1_addr(spr1_addr), .spr1_cs(spr1_cs), .spr1_data(spr1_data), .spr1_ok(spr1_ok),
    .spr2_addr(spr2_addr), .spr2_cs(spr2_cs), .spr2_data(32'd0), .spr2_ok(1'b0),
    .scale_addr(scale_addr), .scale_data(scale_data) );

endmodule
