`timescale 1ns/1ps
module jtbbusters_video #(parameter
    NOBJ     = 2,
    PF_COLW  = 7,
    PF_VAW   = 12,
    PALW     = 11,
    [10:0] PF1_BASE = 11'd768,  PF2_BASE = 11'd1280,
    [10:0] OBJ1_BASE = 11'd256, OBJ2_BASE = 11'd512
)(
    input             rst,
    input             clk,
    output reg        pxl2_cen,
    output reg        pxl_cen,
    output            LHBL, LVBL, HS, VS,
    output     [ 8:0] vdump, hdump,
    output reg [ 3:0] red, green, blue,
    input      [ 3:0] gfx_en,

    input      [15:0] scr1x, scr1y, scr2x, scr2y,
    input             txpage,

    output     [11:1] tx_vaddr,     input [15:0] tx_vq,
    output     [PF_VAW:1] pf1_vaddr, input [15:0] pf1_vq,
    output     [PF_VAW:1] pf2_vaddr, input [15:0] pf2_vq,
    output     [11:1] pal_vaddr,    input [15:0] pal_vq,
    output     [11:1] spr1_vaddr,   input [15:0] spr1_vq,
    output     [11:1] spr2_vaddr,   input [15:0] spr2_vq,

    output     [16:2] tx_addr,  output tx_cs,  input [31:0] tx_data,  input tx_ok,
    output     [18:2] bg1_addr, output bg1_cs, input [31:0] bg1_data, input bg1_ok,
    output     [18:2] bg2_addr, output bg2_cs, input [31:0] bg2_data, input bg2_ok,
    output     [20:2] spr1_addr, output spr1_cs, input [31:0] spr1_data, input spr1_ok,
    output     [20:2] spr2_addr, output spr2_cs, input [31:0] spr2_data, input spr2_ok,

    output reg [15:0] scale_addr,
    input      [ 7:0] scale_data
);

reg [2:0] cnt = 0;
always @(posedge clk) begin
    cnt      <= cnt + 3'd1;
    pxl_cen  <= cnt == 3'd0;
    pxl2_cen <= cnt[1:0] == 2'd0;
end

wire [8:0] vrender, vrender1;
wire       Hinit, Vinit;
jtframe_vtimer #(
    .V_START  ( 9'd16  ), .VB_START ( 9'd239 ), .VB_END ( 9'd279 ),

    .VS_START ( 9'd256 ), .VS_END   ( 9'd264 ), .VCNT_END ( 9'd279 ),
    .HCNT_START( 9'd0  ), .HCNT_END ( 9'd383 ),
    .HB_START ( 9'd255 ), .HB_END   ( 9'd383 ),
    .HS_START ( 9'd296 ), .HS_END   ( 9'd324 ),
    .H_VNEXT  ( 9'd300 )
) u_vtimer(
    .clk(clk), .pxl_cen(pxl_cen), .vdump(vdump), .vrender(vrender), .vrender1(vrender1),
    .H(hdump), .Hinit(Hinit), .Vinit(Vinit), .LHBL(LHBL), .LVBL(LVBL), .HS(HS), .VS(VS)
);

reg  [8:0] vdump_l;
reg        start;
wire [8:0] vr = vdump == 9'd279 ? 9'd16 : vdump + 9'd1;
always @(posedge clk) begin
    vdump_l <= vdump;
    start   <= vdump != vdump_l;
end
wire wbank = vr[0], rbank = vdump[0];

wire [7:0] txw_a, p1w_a, p2w_a, txw_d, p1w_d, p2w_d;
wire       txw_we, p1w_we, p2w_we;
wire [10:0] txva;
wire [PF_VAW-1:0] p1va, p2va;
assign tx_vaddr  = txva;
assign pf1_vaddr = p1va;
assign pf2_vaddr = p2va;

jtbbusters_tilelayer #(.TILE16(0), .VAW(11), .RAW(15)) u_tx(
    .rst(rst), .clk(clk), .start(start), .vr(vr), .scrx(16'd0), .scry(16'd0), .page(txpage),
    .vram_addr(txva), .vram_q(tx_vq),
    .rom_addr(tx_addr), .rom_cs(tx_cs), .rom_data(tx_data), .rom_ok(tx_ok),
    .lb_addr(txw_a), .lb_data(txw_d), .lb_we(txw_we), .busy());
jtbbusters_tilelayer #(.TILE16(1), .COLW(PF_COLW), .VAW(PF_VAW), .RAW(17)) u_pf1(
    .rst(rst), .clk(clk), .start(start), .vr(vr), .scrx(scr1x), .scry(scr1y), .page(1'b0),
    .vram_addr(p1va), .vram_q(pf1_vq),
    .rom_addr(bg1_addr), .rom_cs(bg1_cs), .rom_data(bg1_data), .rom_ok(bg1_ok),
    .lb_addr(p1w_a), .lb_data(p1w_d), .lb_we(p1w_we), .busy());
jtbbusters_tilelayer #(.TILE16(1), .COLW(PF_COLW), .VAW(PF_VAW), .RAW(17)) u_pf2(
    .rst(rst), .clk(clk), .start(start), .vr(vr), .scrx(scr2x), .scry(scr2y), .page(1'b0),
    .vram_addr(p2va), .vram_q(pf2_vq),
    .rom_addr(bg2_addr), .rom_cs(bg2_cs), .rom_data(bg2_data), .rom_ok(bg2_ok),
    .lb_addr(p2w_a), .lb_data(p2w_d), .lb_we(p2w_we), .busy());

wire [7:0]  o1w_a, o2w_a, o1w_d, o2w_d;
wire        o1w_we, o2w_we;
wire        s1_req, s2_req;
wire [15:0] s1_addr, s2_addr;
reg         s1_ack, s2_ack;

jtbbusters_obj u_obj1(
    .rst(rst), .clk(clk), .LVBL(LVBL), .start(start), .vr(vr),
    .ram_addr(spr1_vaddr), .ram_q(spr1_vq),
    .scl_req(s1_req), .scl_addr(s1_addr), .scl_ack(s1_ack), .scl_data(scale_data),
    .rom_addr(spr1_addr), .rom_cs(spr1_cs), .rom_data(spr1_data), .rom_ok(spr1_ok),
    .lb_addr(o1w_a), .lb_data(o1w_d), .lb_we(o1w_we), .busy());

generate if( NOBJ == 2 ) begin : g_obj2
    jtbbusters_obj u_obj2(
        .rst(rst), .clk(clk), .LVBL(LVBL), .start(start), .vr(vr),
        .ram_addr(spr2_vaddr), .ram_q(spr2_vq),
        .scl_req(s2_req), .scl_addr(s2_addr), .scl_ack(s2_ack), .scl_data(scale_data),
        .rom_addr(spr2_addr), .rom_cs(spr2_cs), .rom_data(spr2_data), .rom_ok(spr2_ok),
        .lb_addr(o2w_a), .lb_data(o2w_d), .lb_we(o2w_we), .busy());
end else begin : g_noobj2
    assign spr2_vaddr = 0; assign spr2_addr = 0; assign spr2_cs = 0;
    assign s2_req = 0; assign s2_addr = 0;
    assign o2w_a = 0; assign o2w_d = 8'hff; assign o2w_we = 0;
end endgenerate

reg turn;
always @(posedge clk, posedge rst) begin
    if( rst ) begin s1_ack <= 0; s2_ack <= 0; turn <= 0; scale_addr <= 0; end
    else begin
        s1_ack <= 0; s2_ack <= 0;
        if( !s1_ack && !s2_ack ) begin
            if( s1_req && (!s2_req || !turn) ) begin scale_addr <= s1_addr; s1_ack <= 1; turn <= 1; end
            else if( s2_req )                  begin scale_addr <= s2_addr; s2_ack <= 1; turn <= 0; end
        end
    end
end

reg  [7:0] rx;
reg        rx_vis;

reg        clr;
wire [7:0] tx_px, p1_px, p2_px, o1_px, o2_px;

jtframe_dual_ram #(.DW(8),.AW(9)) u_lbtx(
    .clk0(clk), .data0(txw_d), .addr0({wbank, txw_a}), .we0(txw_we), .q0(),
    .clk1(clk), .data1(8'h00), .addr1({rbank, rx}), .we1(1'b0), .q1(tx_px));
jtframe_dual_ram #(.DW(8),.AW(9)) u_lbp1(
    .clk0(clk), .data0(p1w_d), .addr0({wbank, p1w_a}), .we0(p1w_we), .q0(),
    .clk1(clk), .data1(8'h00), .addr1({rbank, rx}), .we1(1'b0), .q1(p1_px));
jtframe_dual_ram #(.DW(8),.AW(9)) u_lbp2(
    .clk0(clk), .data0(p2w_d), .addr0({wbank, p2w_a}), .we0(p2w_we), .q0(),
    .clk1(clk), .data1(8'h00), .addr1({rbank, rx}), .we1(1'b0), .q1(p2_px));

jtframe_dual_ram #(.DW(8),.AW(9)) u_lbo1(
    .clk0(clk), .data0(o1w_d), .addr0({wbank, o1w_a}), .we0(o1w_we), .q0(),
    .clk1(clk), .data1(8'hff), .addr1({rbank, rx}), .we1(clr), .q1(o1_px));
jtframe_dual_ram #(.DW(8),.AW(9)) u_lbo2(
    .clk0(clk), .data0(o2w_d), .addr0({wbank, o2w_a}), .we0(o2w_we), .q0(),
    .clk1(clk), .data1(8'hff), .addr1({rbank, rx}), .we1(clr), .q1(o2_px));

reg  [2:0] ph;
reg  [10:0] idx;
reg  [3:0] r_n, g_n, b_n;
wire [8:0] hnext2 = hdump >= 9'd382 ? hdump - 9'd382 : hdump + 9'd2;
wire op1 = o1_px[3:0] != 4'hf && gfx_en[3];
wire op2 = o2_px[3:0] != 4'hf && gfx_en[3] && NOBJ == 2;
wire op_last = NOBJ == 2 ? op2 : op1;
wire [7:0] last_px = NOBJ == 2 ? o2_px : o1_px;
wire [10:0] last_base = NOBJ == 2 ? OBJ2_BASE : OBJ1_BASE;

assign pal_vaddr = idx[PALW-1:0];

always @(posedge clk) begin
    ph  <= pxl_cen ? 3'd1 : ph + 3'd1;
    clr <= 0;
    if( pxl_cen ) begin
        rx <= hnext2[7:0];
        rx_vis <= hnext2 < 9'd256;
        { red, green, blue } <= { r_n, g_n, b_n };
    end
    if( ph == 3'd2 ) begin
        idx <= gfx_en[2] ? PF2_BASE + {3'd0, p2_px} : 11'd0;
        if( op_last && last_px[7:6] == 2'b11 ) idx <= last_base + {3'd0, last_px};
        if( p1_px[3:0] != 4'hf && gfx_en[1] ) idx <= PF1_BASE + {3'd0, p1_px};
        if( op_last && last_px[7:6] != 2'b11 ) idx <= last_base + {3'd0, last_px};
        if( NOBJ == 2 && op1 ) idx <= OBJ1_BASE + {3'd0, o1_px};
        if( tx_px[3:0] != 4'hf && gfx_en[0] ) idx <= {3'd0, tx_px};
        clr <= rx_vis;
    end
    if( ph == 3'd4 ) begin
        r_n <= pal_vq[15:12]; g_n <= pal_vq[11:8]; b_n <= pal_vq[7:4];
    end
end

endmodule
