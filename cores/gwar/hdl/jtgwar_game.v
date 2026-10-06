module jtgwar_game(
    `include "jtframe_game_ports.inc"
);

reg [3:0] cnt12 = 0;
always @(posedge clk) cnt12 <= cnt12 == 4'd11 ? 4'd0 : cnt12 + 4'd1;
assign pxl_cen  = cnt12 == 4'd0 || cnt12 == 4'd6;
assign pxl2_cen = cnt12 == 4'd0 || cnt12 == 4'd3 || cnt12 == 4'd6 || cnt12 == 4'd9;
wire cen_a   = cnt12 == 4'd1;
wire cen_b   = cnt12 == 4'd7;
wire cen_snd = cnt12 == 4'd4;

localparam [3:0] ROT_REP = 4'd5;
reg  [3:0] rot1 = 0, rot2 = 0, rep1 = 0, rep2 = 0;
reg  [1:0] rb1_l = 2'b11, rb2_l = 2'b11;
reg        lvbl_l = 0;
wire [1:0] rb1 = joystick1[7:6], rb2 = joystick2[7:6];

function [3:0] rot_step( input [3:0] p, input dir );
    rot_step = dir ? (p == 4'd11 ? 4'd0 : p + 4'd1) : (p == 4'd0 ? 4'd11 : p - 4'd1);
endfunction

always @(posedge clk) begin
    lvbl_l <= LVBL;
    rb1_l  <= rb1;  rb2_l <= rb2;
    if( rst ) begin
        rot1 <= 0; rot2 <= 0; rep1 <= 0; rep2 <= 0;
    end else begin

        if( rb1[0] == 0 && rb1_l[0] ) begin rot1 <= rot_step( rot1, 1'b0 ); rep1 <= ROT_REP<<1; end
        else if( rb1[1] == 0 && rb1_l[1] ) begin rot1 <= rot_step( rot1, 1'b1 ); rep1 <= ROT_REP<<1; end
        if( rb2[0] == 0 && rb2_l[0] ) begin rot2 <= rot_step( rot2, 1'b0 ); rep2 <= ROT_REP<<1; end
        else if( rb2[1] == 0 && rb2_l[1] ) begin rot2 <= rot_step( rot2, 1'b1 ); rep2 <= ROT_REP<<1; end

        if( !LVBL && lvbl_l ) begin
            if( rb1 != 2'b11 ) begin
                if( rep1 != 0 ) rep1 <= rep1 - 4'd1;
                else begin rot1 <= rot_step( rot1, rb1[0] ); rep1 <= ROT_REP; end
            end
            if( rb2 != 2'b11 ) begin
                if( rep2 != 0 ) rep2 <= rep2 - 4'd1;
                else begin rot2 <= rot_step( rot2, rb2[0] ); rep2 <= ROT_REP; end
            end
        end
    end
end

wire [7:0] in0 = { cab_1p[0], cab_1p[1], coin[0], coin[1], dip_test, tilt, service, 1'b0 };

wire [7:0] in3 = { 3'b111, joystick2[5], joystick2[4], 1'b1, joystick1[5], joystick1[4] };

wire [ 7:0] snd_latch;
wire        snd_wr, snd_busy;
wire [ 8:0] bg_scrollx, bg_scrolly, sp16_scrollx, sp16_scrolly, sp32_scrollx, sp32_scrolly;
wire [ 7:0] split, txbank;
wire        flip;
wire [10:0] vbg_addr, vtx_addr;
wire [ 7:0] vbg_data, vtx_data;
wire [ 6:0] vspr_addr;
wire [31:0] vspr_data;
wire [15:0] dbg_a, dbg_b;
wire [ 7:0] snd_dbg;
wire [11:0] obj_cycles;

assign dip_flip = flip;

gwar_main u_main(
    .rst        ( rst         ),
    .clk        ( clk         ),
    .cen_a      ( cen_a       ),
    .cen_b      ( cen_b       ),
    .LVBL       ( LVBL        ),
    .main_addr  ( main_addr   ), .main_cs( main_cs ), .main_data( main_data ), .main_ok( main_ok ),
    .sub_addr   ( sub_addr    ), .sub_cs ( sub_cs  ), .sub_data ( sub_data  ), .sub_ok ( sub_ok  ),
    .in0        ( in0         ),
    .joy1       ( joystick1[3:0] ),
    .joy2       ( joystick2[3:0] ),
    .in3        ( in3         ),
    .dsw1       ( dipsw[ 7:0] ),
    .dsw2       ( dipsw[15:8] ),
    .rot1       ( rot1        ),
    .rot2       ( rot2        ),
    .snd_latch  ( snd_latch   ),
    .snd_wr     ( snd_wr      ),
    .snd_busy   ( snd_busy    ),
    .bg_scrollx ( bg_scrollx  ), .bg_scrolly  ( bg_scrolly   ),
    .sp16_scrollx( sp16_scrollx ), .sp16_scrolly( sp16_scrolly ),
    .sp32_scrollx( sp32_scrollx ), .sp32_scrolly( sp32_scrolly ),
    .split      ( split       ),
    .txbank     ( txbank      ),
    .flip       ( flip        ),
    .vbg_addr   ( vbg_addr    ), .vbg_data ( vbg_data  ),
    .vtx_addr   ( vtx_addr    ), .vtx_data ( vtx_data  ),
    .vspr_addr  ( vspr_addr   ), .vspr_data( vspr_data ),
    .dbg_a      ( dbg_a       ),
    .dbg_b      ( dbg_b       )
);

`ifndef NOSOUND
gwar_sound u_sound(
    .rst        ( rst         ),
    .clk        ( clk         ),
    .cen        ( cen_snd     ),
    .latch      ( snd_latch   ),
    .latch_wr   ( snd_wr      ),
    .busy       ( snd_busy    ),
    .rom_addr   ( snd_addr    ), .rom_cs( snd_cs ), .rom_data( snd_data ), .rom_ok( snd_ok ),
    .pcm_addr   ( pcm_addr    ), .pcm_cs( pcm_cs ), .pcm_data( pcm_data ), .pcm_ok( pcm_ok ),
    .ym1        ( ym1         ),
    .ym2        ( ym2         ),
    .dbg        ( snd_dbg     )
);
`else
assign snd_busy = 0; assign snd_cs = 0; assign snd_addr = 0; assign pcm_cs = 0; assign pcm_addr = 0;
assign ym1 = 0; assign ym2 = 0; assign snd_dbg = 0;
`endif

wire [9:0] pal_addr;
wire [10:0] op16_addr; wire [9:0] op32_addr; wire op16, op32;

`ifdef SIMULATION
localparam BLANK_EN = 1'b0;
`else
localparam BLANK_EN = 1'b1;
`endif
gwar_blankmap u_blank(
    .clk( clk ), .ioctl_addr( ioctl_addr ), .prog_data( prog_data[7:0] ), .prog_we( prog_we ),
    .op16_addr( op16_addr ), .op16( op16 ), .op32_addr( op32_addr ), .op32( op32 )
);
assign palr_addr = pal_addr;
assign palg_addr = pal_addr;
assign palb_addr = pal_addr;

gwar_video u_video(
    .rst        ( rst         ),
    .clk        ( clk         ),
    .pxl_cen    ( pxl_cen     ),
    .bg_scrollx ( bg_scrollx  ), .bg_scrolly  ( bg_scrolly   ),
    .sp16_scrollx( sp16_scrollx ), .sp16_scrolly( sp16_scrolly ),
    .sp32_scrollx( sp32_scrollx ), .sp32_scrolly( sp32_scrolly ),
    .split      ( split       ),
    .txbank     ( txbank      ),
    .flip       ( flip        ),
    .vbg_addr   ( vbg_addr    ), .vbg_data ( vbg_data  ),
    .vtx_addr   ( vtx_addr    ), .vtx_data ( vtx_data  ),
    .vspr_addr  ( vspr_addr   ), .vspr_data( vspr_data ),
    .bgrom_addr ( bgrom_addr  ), .bgrom_cs ( bgrom_cs  ), .bgrom_data ( bgrom_data  ), .bgrom_ok ( bgrom_ok  ),
    .s16rom_addr( s16rom_addr ), .s16rom_cs( s16rom_cs ), .s16rom_data( s16rom_data ), .s16rom_ok( s16rom_ok ),
    .s32rom_addr( s32rom_addr ), .s32rom_cs( s32rom_cs ), .s32rom_data( s32rom_data ), .s32rom_ok( s32rom_ok ),
    .blank_en   ( BLANK_EN    ),
    .op16_addr  ( op16_addr   ), .op16( op16 ), .op32_addr( op32_addr ), .op32( op32 ),
    .txrom_addr ( txrom_addr  ), .txrom_data( txrom_data ),
    .pal_addr   ( pal_addr    ),
    .palr       ( palr_data[3:0] ), .palg( palg_data[3:0] ), .palb( palb_data[3:0] ),
    .LHBL       ( LHBL        ),
    .LVBL       ( LVBL        ),
    .HS         ( HS          ),
    .VS         ( VS          ),
    .red        ( red         ),
    .green      ( green       ),
    .blue       ( blue        ),
    .gfx_en     ( gfx_en      ),
    .obj_cycles ( obj_cycles  )
);

reg [7:0] dbgv;
always @(*) case( debug_bus[1:0] )
    2'd0: dbgv = dbg_a[15:8];
    2'd1: dbgv = dbg_b[15:8];
    2'd2: dbgv = snd_dbg;
    default: dbgv = obj_cycles[11:4];
endcase
assign debug_view = dbgv;

endmodule
