`timescale 1ns/1ps
module jtbbusters_main(
    input             rst,
    input             clk,
    input             LVBL,
    input             dip_pause,

    output            main_cs,
    output     [18:1] main_addr,
    input      [15:0] main_data,
    input             main_ok,

    input      [ 7:0] in_coins, in_0, in_1, in_dsw1, in_dsw2,
    input      [ 9:0] gun_x1, gun_y1, gun_x2, gun_y2, gun_x3, gun_y3,

    output reg [ 2:0] recoil,
    output reg [ 1:0] coin_cnt,

    output reg [ 7:0] snd_latch,
    output reg        snd_latch_we,
    input      [ 7:0] snd_reply,

    output     [ 6:0] nvram_addr,
    output     [ 7:0] nvram_din,
    output            nvram_we,
    input      [ 7:0] nvram_dout,

    input      [11:1] tx_vaddr,   output [15:0] tx_vq,
    input      [12:1] pf1_vaddr,  output [15:0] pf1_vq,
    input      [12:1] pf2_vaddr,  output [15:0] pf2_vq,
    input      [11:1] pal_vaddr,  output [15:0] pal_vq,
    input      [11:1] spr1_vaddr, output [15:0] spr1_vq,
    input      [11:1] spr2_vaddr, output [15:0] spr2_vq,
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
wire        bus_busy;

wire as      = ~ASn;
wire inta    = as & (&FC);
wire VPAn    = ~inta;
wire [1:0] bwe = (as & ~RnW & ~inta) ? ~dsn : 2'b00;

wire [7:0] seg = A[23:16];
wire rom_cs   = as & ~inta & (seg <= 8'h07);
wire wram_cs  = as & ~inta & (seg == 8'h08);
wire tx_cs    = as & ~inta & (seg == 8'h09) & (A[15:12] == 4'h0);
wire page_cs  = as & ~inta & (seg == 8'h09) & (A[15:1] == 15'h4000);
wire spr1_cs  = as & ~inta & (seg == 8'h0A) & ~A[15];
wire spr2_cs  = as & ~inta & (seg == 8'h0A) &  A[15];
wire pf1_cs   = as & ~inta & (seg == 8'h0B) & (A[15:13] == 3'b000);
wire pf2_cs   = as & ~inta & (seg == 8'h0B) & (A[15:13] == 3'b001);
wire bram_cs  = as & ~inta & (seg == 8'h0B) & (A[15:13] == 3'b010);
wire scr_cs   = as & ~inta & (seg == 8'h0B) & (A[15:4] == 12'h800);
wire pal_cs   = as & ~inta & (seg == 8'h0D) & (A[15:12] == 4'h0);
wire in_cs    = as & ~inta & (seg == 8'h0E) & ~A[15];
wire adc_cs   = as & ~inta & (seg == 8'h0E) &  A[15] & (A[14:2] == 13'd0);
wire out_cs   = as & ~inta & (seg == 8'h0F) & ~A[15];
wire eep_cs   = as & ~inta & (seg == 8'h0F) &  A[15] & (A[14:8] == 7'd0);

assign main_cs   = rom_cs;
assign main_addr = A[18:1];
assign bus_busy  = rom_cs & ~main_ok;

wire [15:0] wram_q;
jtframe_ram16 #(.AW(15)) u_wram(
    .clk(clk), .data(cpu_dout), .addr(A[15:1]), .we(wram_cs ? bwe : 2'b00), .q(wram_q));

wire [15:0] tx_q, spr1_q, spr2_q, pf1_q, pf2_q, pal_q, bram_q;
jtframe_dual_ram16 #(.AW(11)) u_tx(
    .clk0(clk), .data0(cpu_dout), .addr0(A[11:1]), .we0(tx_cs ? bwe : 2'b00), .q0(tx_q),
    .clk1(clk), .data1(16'd0), .addr1(tx_vaddr), .we1(2'b00), .q1(tx_vq));

jtframe_dual_ram16 #(.AW(14)) u_spr1(
    .clk0(clk), .data0(cpu_dout), .addr0(A[14:1]), .we0(spr1_cs ? bwe : 2'b00), .q0(spr1_q),
    .clk1(clk), .data1(16'd0), .addr1({3'd0, spr1_vaddr}), .we1(2'b00), .q1(spr1_vq));
jtframe_dual_ram16 #(.AW(14)) u_spr2(
    .clk0(clk), .data0(cpu_dout), .addr0(A[14:1]), .we0(spr2_cs ? bwe : 2'b00), .q0(spr2_q),
    .clk1(clk), .data1(16'd0), .addr1({3'd0, spr2_vaddr}), .we1(2'b00), .q1(spr2_vq));
jtframe_dual_ram16 #(.AW(12)) u_pf1(
    .clk0(clk), .data0(cpu_dout), .addr0(A[12:1]), .we0(pf1_cs ? bwe : 2'b00), .q0(pf1_q),
    .clk1(clk), .data1(16'd0), .addr1(pf1_vaddr), .we1(2'b00), .q1(pf1_vq));
jtframe_dual_ram16 #(.AW(12)) u_pf2(
    .clk0(clk), .data0(cpu_dout), .addr0(A[12:1]), .we0(pf2_cs ? bwe : 2'b00), .q0(pf2_q),
    .clk1(clk), .data1(16'd0), .addr1(pf2_vaddr), .we1(2'b00), .q1(pf2_vq));
jtframe_dual_ram16 #(.AW(11)) u_pal(
    .clk0(clk), .data0(cpu_dout), .addr0(A[11:1]), .we0(pal_cs ? bwe : 2'b00), .q0(pal_q),
    .clk1(clk), .data1(16'd0), .addr1(pal_vaddr), .we1(2'b00), .q1(pal_vq));
jtframe_ram16 #(.AW(12)) u_bram(
    .clk(clk), .data(cpu_dout), .addr(A[12:1]), .we(bram_cs ? bwe : 2'b00), .q(bram_q));

assign nvram_addr = A[7:1];
assign nvram_din  = cpu_dout[7:0];
assign nvram_we   = eep_cs & ~RnW & ~dsn[0];

wire [7:0] adc_dout;
wire       adc_eoc_ff;
reg        adc_rd_l;
wire       adc_rd = adc_cs &  RnW & ~dsn[0];
wire       adc_wr = adc_cs & ~RnW & ~dsn[0];
reg        adc_wr_l;
always @(posedge clk) begin adc_rd_l <= adc_rd; adc_wr_l <= adc_wr; end
jtbbusters_upd7004 u_adc(
    .rst    ( rst           ),
    .clk    ( clk           ),
    .offset ( A[1]          ),
    .rd     ( adc_rd & ~adc_rd_l ),
    .wr     ( adc_wr & ~adc_wr_l ),
    .din    ( cpu_dout[7:0] ),
    .dout   ( adc_dout      ),
    .eoc_ff ( adc_eoc_ff    ),

    .ch0(gun_y1), .ch1(gun_x1), .ch2(gun_y2), .ch3(gun_x2), .ch4(gun_y3), .ch5(gun_x3),
    .ch6(10'd0),  .ch7(10'd0)
);

reg snd_we_l;
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        scr1x <= 0; scr1y <= 0; scr2x <= 0; scr2y <= 0;
        txpage <= 0; recoil <= 0; coin_cnt <= 0;
        snd_latch <= 0; snd_latch_we <= 0; snd_we_l <= 0;
    end else begin
        snd_latch_we <= 0;
        if( |bwe ) begin
            if( scr_cs ) case( A[3:1] )
                3'd0: scr1x <= cpu_dout;
                3'd1: scr1y <= cpu_dout;
                3'd4: scr2x <= cpu_dout;
                3'd5: scr2y <= cpu_dout;
                default:;
            endcase
            if( page_cs ) txpage <= cpu_dout[0];
            if( out_cs ) case( A[4:1] )
                4'h0: coin_cnt <= cpu_dout[1:0];
                4'h4: recoil   <= cpu_dout[2:0];
                default:;
            endcase
        end

        snd_we_l <= out_cs & ~RnW & ~dsn[0] & (A[4:1] == 4'hC);
        if( out_cs & ~RnW & ~dsn[0] & (A[4:1] == 4'hC) & ~snd_we_l ) begin
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
    if( spr1_cs ) cpu_din = spr1_q;
    if( spr2_cs ) cpu_din = spr2_q;
    if( pf1_cs  ) cpu_din = pf1_q;
    if( pf2_cs  ) cpu_din = pf2_q;
    if( bram_cs ) cpu_din = bram_q;
    if( pal_cs  ) cpu_din = pal_q;
    if( in_cs   ) case( A[4:1] )
        4'h0: cpu_din = { 8'h00, in_coins };
        4'h1: cpu_din = { 8'h00, in_0     };
        4'h2: cpu_din = { 8'h00, in_1     };
        4'h4: cpu_din = { 8'h00, in_dsw1  };
        4'h5: cpu_din = { 8'h00, in_dsw2  };
        4'hC: cpu_din = { 8'h00, snd_reply};
        default: cpu_din = 16'h0000;
    endcase
    if( adc_cs  ) cpu_din = { 8'hff, adc_dout };
    if( eep_cs  ) cpu_din = { 8'hff, nvram_dout };
end

reg irq6, lvbl_l;
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        irq6 <= 0; lvbl_l <= 1;
    end else begin
        lvbl_l <= LVBL;
        if( lvbl_l & ~LVBL ) irq6 <= 1;
        else if( inta && A[3:1] == 3'd6 ) irq6 <= 0;
    end
end
always @(posedge clk) IPLn <= irq6 ? 3'b001 : adc_eoc_ff ? 3'b101 : 3'b111;

`ifdef SIMULATION

integer frame_cnt = 0;
reg     io_l = 0;
wire    io_acc = as & ~inta & (page_cs | in_cs | adc_cs | out_cs | eep_cs);
always @(posedge clk) begin
    if( lvbl_l & ~LVBL ) frame_cnt <= frame_cnt + 1;
    io_l <= io_acc & ~DTACKn;
    if( io_acc & ~DTACKn & ~io_l )
        $display("IOTRACE cuadro=%0d %s %06x dato=%04x", frame_cnt, RnW ? "R" : "W", {A,1'b0},
                 RnW ? cpu_din : cpu_dout);
end
`endif

jtframe_68kdtack_cen #(.W(8)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( rom_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( 1'b0      ),
    .bus_ack    ( 1'b0      ),
    .ASn        ( ASn       ),
    .DSn        ( dsn       ),
    .num        ( 7'd1      ),
    .den        ( 8'd4      ),
    .DTACKn     ( DTACKn    ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    .fave       (           ),
    .fworst     (           )
);

jtframe_m68k u_cpu(
    .clk        ( clk         ),
    .rst        ( rst         ),
    .RESETn     (             ),
    .cpu_cen    ( cpu_cen     ),
    .cpu_cenb   ( cpu_cenb    ),
    .eab        ( A           ),
    .iEdb       ( cpu_din     ),
    .oEdb       ( cpu_dout    ),
    .eRWn       ( RnW         ),
    .LDSn       ( dsn[0]      ),
    .UDSn       ( dsn[1]      ),
    .ASn        ( ASn         ),
    .VPAn       ( VPAn        ),
    .FC         ( FC          ),
    .BERRn      ( 1'b1        ),
    .HALTn      ( dip_pause   ),
    .BRn        ( 1'b1        ),
    .BGACKn     ( 1'b1        ),
    .BGn        (             ),
    .DTACKn     ( DTACKn      ),
    .IPLn       ( IPLn        )
);

endmodule
