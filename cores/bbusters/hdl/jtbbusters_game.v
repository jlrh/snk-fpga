`timescale 1ns/1ps
module jtbbusters_game(
    `include "jtframe_game_ports.inc"
);

wire [7:0] in_coins = { 1'b1, service, 2'b11, coin[3:0] };
wire [7:0] in_0     = { 1'b1, joystick2[5], joystick2[4], cab_1p[1],
                        1'b1, joystick1[5], joystick1[4], cab_1p[0] };
wire [7:0] in_1     = { 5'b11111, joystick3[5], joystick3[4], cab_1p[2] };
wire [7:0] in_dsw1  = dipsw[7:0];
wire [7:0] in_dsw2  = { dipsw[15] & dip_test, dipsw[14:8] };

function [9:0] gun_h( input [8:0] x, input [9:0] lo, input [9:0] md, input [9:0] hi );
    reg [16:0] m;
    begin
        m     = x[7] ? x[6:0] * (hi - md) : x[6:0] * (md - lo);
        gun_h = x[8] ? hi : (x[7] ? md : lo) + m[16:7];
    end
endfunction
function [9:0] gun_v( input [8:0] y, input [9:0] lo, input [9:0] md, input [9:0] hi );
    reg [8:0]  t;
    reg [25:0] m;
    begin
        t     = y >= 9'd112 ? y - 9'd112 : y;
        m     = y >= 9'd112 ? t * (hi - md) * 10'd585 : t * (md - lo) * 10'd585;
        gun_v = y >= 9'd224 ? hi : (y >= 9'd112 ? md : lo) + m[25:16];
    end
endfunction
wire [ 8:0] ana3_x  = { 1'b0, ~joyana_l3[7], joyana_l3[6:0] };
wire [10:0] ana3_y7 = { ~joyana_l3[15], joyana_l3[14:8] } * 3'd7;
wire [ 8:0] ana3_y  = { 1'b0, ana3_y7[10:3] };
wire [9:0] gun_x1 = gun_h( gun_1p_x, 10'h136, 10'h23a, 10'h36a ), gun_y1 = gun_v( gun_1p_y, 10'h0e6, 10'h1a6, 10'h272 );
wire [9:0] gun_x2 = gun_h( gun_2p_x, 10'h10e, 10'h1de, 10'h2e2 ), gun_y2 = gun_v( gun_2p_y, 10'h146, 10'h1f6, 10'h2aa );
wire [9:0] gun_x3 = gun_h( ana3_x,   10'h14e, 10'h212, 10'h33e ), gun_y3 = gun_v( ana3_y,   10'h16e, 10'h21e, 10'h2f6 );

wire [ 7:0] snd_latch, snd_reply;
wire        snd_latch_we;
wire [ 2:0] recoil;
wire [ 1:0] coin_cnt;
wire [11:1] tx_vaddr, pal_vaddr, spr1_vaddr, spr2_vaddr;
wire [12:1] pf1_vaddr, pf2_vaddr;
wire [15:0] tx_vq, pf1_vq, pf2_vq, pal_vq, spr1_vq, spr2_vq;
wire [15:0] scr1x, scr1y, scr2x, scr2y;
wire        txpage;
wire [ 8:0] vdump, hdump;

assign dip_flip   = 1'b0;
assign debug_view = { 5'd0, txpage, coin_cnt };
assign ioctl_din  = 8'd0;

jtbbusters_main u_main(
    .rst          ( rst          ),
    .clk          ( clk          ),
    .LVBL         ( LVBL         ),
    .dip_pause    ( dip_pause    ),
    .main_cs      ( main_cs      ),
    .main_addr    ( main_addr    ),
    .main_data    ( main_data    ),
    .main_ok      ( main_ok      ),
    .in_coins     ( in_coins     ),
    .in_0         ( in_0         ),
    .in_1         ( in_1         ),
    .in_dsw1      ( in_dsw1      ),
    .in_dsw2      ( in_dsw2      ),
    .gun_x1(gun_x1), .gun_y1(gun_y1), .gun_x2(gun_x2), .gun_y2(gun_y2), .gun_x3(gun_x3), .gun_y3(gun_y3),
    .recoil       ( recoil       ),
    .coin_cnt     ( coin_cnt     ),
    .snd_latch    ( snd_latch    ),
    .snd_latch_we ( snd_latch_we ),
    .snd_reply    ( snd_reply    ),
    .nvram_addr   ( nvram_addr   ),
    .nvram_din    ( nvram_din    ),
    .nvram_we     ( nvram_we     ),
    .nvram_dout   ( nvram_dout   ),
    .tx_vaddr(tx_vaddr),     .tx_vq(tx_vq),
    .pf1_vaddr(pf1_vaddr),   .pf1_vq(pf1_vq),
    .pf2_vaddr(pf2_vaddr),   .pf2_vq(pf2_vq),
    .pal_vaddr(pal_vaddr),   .pal_vq(pal_vq),
    .spr1_vaddr(spr1_vaddr), .spr1_vq(spr1_vq),
    .spr2_vaddr(spr2_vaddr), .spr2_vq(spr2_vq),
    .scr1x(scr1x), .scr1y(scr1y), .scr2x(scr2x), .scr2y(scr2y),
    .txpage       ( txpage       )
);

wire signed [15:0] snd_l, snd_r;
jtbbusters_sound u_sound(
    .rst        ( rst          ),
    .clk        ( clk          ),
    .latch_in   ( snd_latch    ),
    .latch_we   ( snd_latch_we ),
    .reply      ( snd_reply    ),
    .snd_cs     ( snd_cs       ),
    .snd_addr   ( snd_addr     ),
    .snd_data   ( snd_data     ),
    .snd_ok     ( snd_ok       ),
    .pcma_cs    ( pcma_cs      ),
    .pcma_addr  ( pcma_addr    ),
    .pcma_data  ( pcma_data    ),
    .pcma_ok    ( pcma_ok      ),
    .pcmb_cs    ( pcmb_cs      ),
    .pcmb_addr  ( pcmb_addr    ),
    .pcmb_data  ( pcmb_data    ),
    .pcmb_ok    ( pcmb_ok      ),
    .snd_left   ( snd_l        ),
    .snd_right  ( snd_r        ),
    .sample     ( sample       )
);

jtframe_dcrm #(.SW(16),.SIGNED_INPUT(1)) u_dcl(.rst(rst), .clk(clk), .sample(sample), .din(snd_l), .dout(snd_left));
jtframe_dcrm #(.SW(16),.SIGNED_INPUT(1)) u_dcr(.rst(rst), .clk(clk), .sample(sample), .din(snd_r), .dout(snd_right));

jtbbusters_video #(.NOBJ(2), .PF_COLW(7), .PF_VAW(12), .PALW(11),
    .PF1_BASE(11'd768), .PF2_BASE(11'd1280), .OBJ1_BASE(11'd256), .OBJ2_BASE(11'd512)
) u_video(
    .rst        ( rst        ),
    .clk        ( clk        ),
    .pxl2_cen   ( pxl2_cen   ),
    .pxl_cen    ( pxl_cen    ),
    .LHBL       ( LHBL       ),
    .LVBL       ( LVBL       ),
    .HS         ( HS         ),
    .VS         ( VS         ),
    .vdump      ( vdump      ),
    .hdump      ( hdump      ),
    .red        ( red        ),
    .green      ( green      ),
    .blue       ( blue       ),
    .gfx_en     ( gfx_en     ),
    .scr1x(scr1x), .scr1y(scr1y), .scr2x(scr2x), .scr2y(scr2y),
    .txpage     ( txpage     ),
    .tx_vaddr(tx_vaddr),     .tx_vq(tx_vq),
    .pf1_vaddr(pf1_vaddr),   .pf1_vq(pf1_vq),
    .pf2_vaddr(pf2_vaddr),   .pf2_vq(pf2_vq),
    .pal_vaddr(pal_vaddr),   .pal_vq(pal_vq),
    .spr1_vaddr(spr1_vaddr), .spr1_vq(spr1_vq),
    .spr2_vaddr(spr2_vaddr), .spr2_vq(spr2_vq),
    .tx_addr(tx_addr),   .tx_cs(tx_cs),   .tx_data(tx_data),   .tx_ok(tx_ok),
    .bg1_addr(bg1_addr), .bg1_cs(bg1_cs), .bg1_data(bg1_data), .bg1_ok(bg1_ok),
    .bg2_addr(bg2_addr), .bg2_cs(bg2_cs), .bg2_data(bg2_data), .bg2_ok(bg2_ok),
    .spr1_addr(spr1_addr), .spr1_cs(spr1_cs), .spr1_data(spr1_data), .spr1_ok(spr1_ok),
    .spr2_addr(spr2_addr), .spr2_cs(spr2_cs), .spr2_data(spr2_data), .spr2_ok(spr2_ok),
    .scale_addr ( scale_addr ),
    .scale_data ( scale_data )
);

endmodule
