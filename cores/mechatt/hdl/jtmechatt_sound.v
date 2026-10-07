`timescale 1ns/1ps
module jtmechatt_sound(
    input                rst,
    input                clk,
    input         [ 7:0] latch_in,
    input                latch_we,
    output reg    [ 7:0] reply,
    output               snd_cs,
    output        [15:0] snd_addr,
    input         [ 7:0] snd_data,
    input                snd_ok,
    output        [12:0] rhy_addr,
    output               rhy_cs,
    input         [ 7:0] rhy_data,
    input                rhy_ok,
    output        [16:0] pcmb_addr,
    output               pcmb_cs,
    input         [ 7:0] pcmb_data,
    input                pcmb_ok,
    output reg signed [15:0] snd_left,
    output reg signed [15:0] snd_right,
    output               sample
);

reg [3:0] cnt12;
reg [2:0] cnt6;
reg       cen_z80, cen_fm;
always @(posedge clk) begin
    cnt12   <= cnt12 == 4'd11 ? 4'd0 : cnt12 + 4'd1;
    cnt6    <= cnt6  == 3'd5  ? 3'd0 : cnt6  + 3'd1;
    cen_z80 <= cnt12 == 4'd0;
    cen_fm  <= cnt6  == 3'd0;
end

wire        m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n, halt_n, busak_n, cpu_cen;
wire [15:0] A;
wire [ 7:0] cpu_dout, ram_dout, fm_dout;
reg  [ 7:0] cpu_din;
wire        int_n;

wire mem_acc  = ~mreq_n & rfsh_n;
wire rom_cs   = mem_acc & (A < 16'hF000);
wire ram_cs   = mem_acc & (A[15:11] == 5'b11110);
wire latch_cs = mem_acc & (A == 16'hF800);
wire io_acc   = ~iorq_n & m1_n;
wire fm_cs    = io_acc & (A[7:2] == 6'd0);

assign snd_cs   = rom_cs;
assign snd_addr = A;

reg  [7:0] latch;
reg  [4:0] nmi_cnt;
wire       nmi_n = nmi_cnt == 0;
reg        wr_l;
always @(posedge clk, posedge rst) begin
    if( rst ) begin latch <= 0; nmi_cnt <= 0; reply <= 0; wr_l <= 1; end
    else begin
        if( latch_we ) begin latch <= latch_in; nmi_cnt <= 5'd16; end
        else if( nmi_cnt != 0 ) nmi_cnt <= nmi_cnt - 1'd1;
        wr_l <= wr_n;
        if( latch_cs && !wr_n && wr_l ) reply <= cpu_dout;
    end
end

`ifdef SIMULATION
always @(posedge clk) begin
    if( latch_we ) $display("SNDTRACE 68k->z80 latch=%02x", latch_in);
    if( latch_cs && !wr_n && wr_l ) $display("SNDTRACE z80->68k reply=%02x", cpu_dout);
end
`endif

always @* begin
    cpu_din = 8'hff;
    if( rom_cs   ) cpu_din = snd_data;
    if( ram_cs   ) cpu_din = ram_dout;
    if( latch_cs ) cpu_din = latch;
    if( fm_cs    ) cpu_din = fm_dout;
end

jtframe_sysz80 #(.RAM_AW(11)) u_cpu(
    .rst_n(~rst), .clk(clk), .cen(cen_z80), .cpu_cen(cpu_cen), .int_n(int_n), .nmi_n(nmi_n), .busrq_n(1'b1),
    .m1_n(m1_n), .mreq_n(mreq_n), .iorq_n(iorq_n), .rd_n(rd_n), .wr_n(wr_n), .rfsh_n(rfsh_n), .halt_n(halt_n),
    .busak_n(busak_n), .A(A), .cpu_din(cpu_din), .cpu_dout(cpu_dout), .ram_dout(ram_dout),
    .ram_cs(ram_cs), .rom_cs(rom_cs), .rom_ok(snd_ok) );

wire signed [15:0] fm_l, fm_r;
wire        [15:0] ssg;
jtmechatt_opna u_fm(
    .rst(rst), .clk(clk), .cen(cen_fm), .din(cpu_dout), .addr(A[1:0]), .cs_n(~fm_cs), .wr_n(wr_n), .rd_n(rd_n),
    .dout(fm_dout), .irq_n(int_n),
    .rhy_addr(rhy_addr), .rhy_cs(rhy_cs), .rhy_data(rhy_data), .rhy_ok(rhy_ok),
    .pcmb_addr(pcmb_addr), .pcmb_cs(pcmb_cs), .pcmb_data(pcmb_data), .pcmb_ok(pcmb_ok),
    .fm_l(fm_l), .fm_r(fm_r), .ssg(ssg), .sample(sample) );

wire signed [25:0] ssg_w = $signed({ 1'b0, ssg }) * 26'sd115;
wire signed [25:0] mix_l = fm_l * 26'sd205 + ssg_w;
wire signed [25:0] mix_r = fm_r * 26'sd205 + ssg_w;
wire signed [17:0] sh_l  = mix_l[25:8], sh_r = mix_r[25:8];
always @(posedge clk) if( sample ) begin
    snd_left  <= sh_l > 18'sd32767 ? 16'sd32767 : sh_l < -18'sd32768 ? -16'sd32768 : sh_l[15:0];
    snd_right <= sh_r > 18'sd32767 ? 16'sd32767 : sh_r < -18'sd32768 ? -16'sd32768 : sh_r[15:0];
end

endmodule
