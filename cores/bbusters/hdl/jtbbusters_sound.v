`timescale 1ns/1ps
module jtbbusters_sound(
    input                rst,
    input                clk,
    input         [ 7:0] latch_in,
    input                latch_we,
    output reg    [ 7:0] reply,

    output               snd_cs,
    output        [15:0] snd_addr,
    input         [ 7:0] snd_data,
    input                snd_ok,

    output               pcma_cs,
    output        [18:0] pcma_addr,
    input         [ 7:0] pcma_data,
    input                pcma_ok,
    output               pcmb_cs,
    output        [18:0] pcmb_addr,
    input         [ 7:0] pcmb_data,
    input                pcmb_ok,
    output signed [15:0] snd_left,
    output signed [15:0] snd_right,
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
    if( rst ) begin
        latch <= 0; nmi_cnt <= 0; reply <= 0; wr_l <= 1;
    end else begin
        if( latch_we ) begin latch <= latch_in; nmi_cnt <= 5'd16; end
        else if( nmi_cnt != 0 ) nmi_cnt <= nmi_cnt - 1'd1;
        wr_l <= wr_n;
        if( latch_cs && !wr_n && wr_l ) reply <= cpu_dout;
    end
end

`ifdef SIMULATION
reg [15:0] nlat = 0;
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
    .rst_n      ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cen_z80   ),
    .cpu_cen    ( cpu_cen   ),
    .int_n      ( int_n     ),
    .nmi_n      ( nmi_n     ),
    .busrq_n    ( 1'b1      ),
    .m1_n       ( m1_n      ),
    .mreq_n     ( mreq_n    ),
    .iorq_n     ( iorq_n    ),
    .rd_n       ( rd_n      ),
    .wr_n       ( wr_n      ),
    .rfsh_n     ( rfsh_n    ),
    .halt_n     ( halt_n    ),
    .busak_n    ( busak_n   ),
    .A          ( A         ),
    .cpu_din    ( cpu_din   ),
    .cpu_dout   ( cpu_dout  ),
    .ram_dout   ( ram_dout  ),
    .ram_cs     ( ram_cs    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( snd_ok    )
);

wire [19:0] adpcma_addr;
wire [ 3:0] adpcma_bank;
wire        adpcma_roe_n, adpcmb_roe_n;
wire [23:0] adpcmb_addr;

assign pcma_cs   = ~adpcma_roe_n;
assign pcma_addr = adpcma_addr[18:0];
assign pcmb_cs   = ~adpcmb_roe_n;
assign pcmb_addr = adpcmb_addr[18:0];

jt10 u_fm(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .cen            ( cen_fm        ),
    .din            ( cpu_dout      ),
    .addr           ( A[1:0]        ),
    .cs_n           ( ~fm_cs        ),
    .wr_n           ( wr_n          ),
    .dout           ( fm_dout       ),
    .irq_n          ( int_n         ),
    .adpcma_addr    ( adpcma_addr   ),
    .adpcma_bank    ( adpcma_bank   ),
    .adpcma_roe_n   ( adpcma_roe_n  ),
    .adpcma_data    ( pcma_data     ),
    .adpcmb_addr    ( adpcmb_addr   ),
    .adpcmb_roe_n   ( adpcmb_roe_n  ),
    .adpcmb_data    ( pcmb_data     ),
    .psg_A          (               ),
    .psg_B          (               ),
    .psg_C          (               ),
    .fm_snd         (               ),
    .psg_snd        (               ),
    .snd_right      ( snd_right     ),
    .snd_left       ( snd_left      ),
    .snd_sample     ( sample        ),
    .ch_enable      ( 6'b11_1111    )
);

endmodule
