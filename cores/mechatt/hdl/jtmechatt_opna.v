`timescale 1ns/1ps
module jtmechatt_opna(
    input                rst,
    input                clk,
    input                cen,
    input         [ 7:0] din,
    input         [ 1:0] addr,
    input                cs_n,
    input                wr_n,
    input                rd_n,
    output reg    [ 7:0] dout,
    output               irq_n,

    output        [12:0] rhy_addr,
    output               rhy_cs,
    input         [ 7:0] rhy_data,
    input                rhy_ok,
    output        [16:0] pcmb_addr,
    output               pcmb_cs,
    input         [ 7:0] pcmb_data,
    input                pcmb_ok,

    output reg signed [15:0] fm_l,
    output reg signed [15:0] fm_r,
    output        [15:0] ssg,
    output               sample
);

wire wr_now = !cs_n && !wr_n;
wire rd_now = !cs_n && !rd_n;
reg  wr_l, rd_l;
wire wr_p = wr_now && !wr_l;
wire rd_p = rd_now && !rd_l;
always @(posedge clk) begin wr_l <= wr_now; rd_l <= rd_now; end

reg  [8:0] areg;
reg  [7:0] irq_en, flag_ctl;
reg  [5:0] st;
reg  [7:0] busy_cnt;
wire       busy = busy_cnt != 0;

wire dlo  = addr == 2'd1 && !areg[8];
wire dhi  = addr == 2'd3 &&  areg[8];
wire to_ssgfm = (dlo && (areg[7:4] == 4'h0 || (areg[7:5] != 3'd0 && areg[7:0] != 8'h29)))
             || (dhi && areg[7:0] > 8'h10);
wire wr_rhy  = wr_p && dlo && areg[7:4] == 4'h1;
wire wr_pcmb = wr_p && dhi && areg[7:4] == 4'h0;
wire wr_fctl = wr_p && dhi && areg[7:0] == 8'h10;
wire wr_irqe = wr_p && dlo && areg[7:0] == 8'h29;
wire clr_all = wr_fctl && din[7];

wire opn_cs_n = cs_n || (addr[0] && !to_ssgfm);

wire        opn_sample, ev_A, ev_B, en_A, en_B, rst_A, rst_B;
wire [ 7:0] psg_dout;
wire [ 9:0] psg_snd;
wire signed [15:0] opn_l, opn_r;

jtmechatt_opn u_opn(
    .rst(rst), .clk(clk), .cen(cen), .din(din), .addr(addr), .cs_n(opn_cs_n), .wr_n(wr_n),
    .psg_dout(psg_dout), .sample(opn_sample),
    .ev_A(ev_A), .ev_B(ev_B), .en_A(en_A), .en_B(en_B), .rst_A(rst_A), .rst_B(rst_B),
    .fm_left(opn_l), .fm_right(opn_r), .psg_snd(psg_snd) );

assign ssg = { 1'b0, psg_snd, 5'd0 };

reg  smp_l, rhy_half;
reg  [1:0] sub;
wire smp_tick = opn_sample && !smp_l;
wire rhy_tick = smp_tick && sub == 2'd2;
always @(posedge clk) begin
    if( rst ) begin smp_l <= 0; sub <= 0; rhy_half <= 0; end
    else begin
        smp_l <= opn_sample;
        if( smp_tick ) begin
            sub <= sub == 2'd2 ? 2'd0 : sub + 2'd1;
            if( sub == 2'd2 ) rhy_half <= ~rhy_half;
        end
    end
end
assign sample = smp_tick;

wire signed [15:0] rhy_l, rhy_r, pcmb_l, pcmb_r;
wire        [ 2:0] pcmb_st;

jtmechatt_rhythm u_rhythm(
    .rst(rst), .clk(clk), .tick(rhy_tick), .half(~rhy_half),
    .wr(wr_rhy), .wreg(areg[3:0]), .wdata(din),
    .rom_addr(rhy_addr), .rom_cs(rhy_cs), .rom_data(rhy_data), .rom_ok(rhy_ok),
    .snd_l(rhy_l), .snd_r(rhy_r) );

jtmechatt_adpcmb #(.AW(17), .RSHIFT(1)) u_adpcmb(
    .rst(rst), .clk(clk), .tick(smp_tick),
    .wr(wr_pcmb), .wreg(areg[3:0]), .wdata(din), .status(pcmb_st), .clr(clr_all),
    .rom_addr(pcmb_addr), .rom_cs(pcmb_cs), .rom_data(pcmb_data), .rom_ok(pcmb_ok),
    .snd_l(pcmb_l), .snd_r(pcmb_r) );

wire [5:0] st_hi  = ( (st & 6'b01_0011) | { pcmb_st[2], 1'b0, pcmb_st[1], pcmb_st[0], 2'b00 } ) & ~{ 1'b0, flag_ctl[4:0] };
wire [7:0] st_lo  = { busy, 5'd0, st[1:0] };
assign irq_n = ~|( st[4:0] & irq_en[4:0] & ~flag_ctl[4:0] );

reg rst_Al, rst_Bl;
always @(posedge clk) begin
    if( rst ) begin
        areg <= 0; irq_en <= 8'h1f; flag_ctl <= 8'h1c; st <= 0; busy_cnt <= 0; rst_Al <= 0; rst_Bl <= 0;
    end else begin
        rst_Al <= rst_A; rst_Bl <= rst_B;
        if( cen && busy ) busy_cnt <= busy_cnt - 1'd1;
        if( wr_p ) begin
            case( addr )
                2'd0: areg <= { 1'b0, din };
                2'd2: areg <= { 1'b1, din };
                default: if( dlo || dhi ) busy_cnt <= 8'd192;
            endcase
            if( wr_irqe ) irq_en <= din;
            if( wr_fctl && !din[7] ) flag_ctl <= din;
        end

        if( rst_A && !rst_Al ) st[0] <= 0;
        if( rst_B && !rst_Bl ) st[1] <= 0;
        if( ev_A && en_A ) st[0] <= 1;
        if( ev_B && en_B ) st[1] <= 1;
        if( rd_p && addr == 2'd2 ) st <= st_hi;
        if( clr_all ) st <= 0;
    end
end

always @* begin
    case( addr )
        2'd0: dout = st_lo;
        2'd1: dout = areg < 9'h10 ? psg_dout : areg == 9'h0ff ? 8'h01 : 8'h00;
        2'd2: dout = { busy, 1'b0, st_hi };
        2'd3: dout = 8'h00;
    endcase
end

wire signed [17:0] sum_l = opn_l + rhy_l + pcmb_l;
wire signed [17:0] sum_r = opn_r + rhy_r + pcmb_r;
always @(posedge clk) if( smp_tick ) begin
    fm_l <= sum_l > 18'sd32767 ? 16'sd32767 : sum_l < -18'sd32768 ? -16'sd32768 : sum_l[15:0];
    fm_r <= sum_r > 18'sd32767 ? 16'sd32767 : sum_r < -18'sd32768 ? -16'sd32768 : sum_r[15:0];
end

`ifdef SIMULATION
always @(posedge clk) if( rd_p ) $display("OPNA R %0d %02x", addr, dout);
`endif

endmodule
