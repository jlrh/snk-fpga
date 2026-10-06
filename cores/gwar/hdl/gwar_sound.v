module gwar_sound(
    input                rst,
    input                clk,
    input                cen,

    input        [ 7:0]  latch,
    input                latch_wr,
    output               busy,

    output       [15:0]  rom_addr,
    output               rom_cs,
    input        [ 7:0]  rom_data,
    input                rom_ok,
    output       [15:0]  pcm_addr,
    output               pcm_cs,
    input        [ 7:0]  pcm_data,
    input                pcm_ok,

    output reg signed [15:0] ym1,
    output signed [15:0] ym2,
    output       [ 7:0]  dbg
);

wire [15:0] A;
wire [ 7:0] dout, ramq, y1_dout, y2_dout;
reg  [ 7:0] din;
wire        mreq_n, rd_n, wr_n, rfsh_n, cpu_cen, iorq_n, m1_n;
reg  [ 3:0] status;
wire        y1_irqn, y2_irqn;
wire signed [15:0] ym1_raw;

wire mem    = !mreq_n && rfsh_n;
wire rom    = mem && A[15:14] != 2'b11;
wire ram    = mem && A[15:12] == 4'hC;
wire lat_cs = mem && A[15:11] == 5'b1110_0;
wire y1_cs  = mem && A[15:11] == 5'b1110_1;
wire y2_cs  = mem && A[15:11] == 5'b1111_0;
wire st_cs  = mem && A[15:11] == 5'b1111_1;

assign rom_addr = A;
assign rom_cs   = rom;
assign busy     = status[2];
assign dbg      = { 4'd0, status };

jtframe_z80_romwait #(.CLR_INT(0)) u_cpu(
    .rst_n   ( ~rst      ),
    .clk     ( clk       ),
    .cen     ( cen       ),
    .cpu_cen ( cpu_cen   ),
    .int_n   ( ~|(status & 4'b1011) ),
    .nmi_n   ( 1'b1      ),
    .busrq_n ( 1'b1      ),
    .m1_n    ( m1_n      ),
    .mreq_n  ( mreq_n    ),
    .iorq_n  ( iorq_n    ),
    .rd_n    ( rd_n      ),
    .wr_n    ( wr_n      ),
    .rfsh_n  ( rfsh_n    ),
    .halt_n  (           ),
    .busak_n (           ),
    .A       ( A         ),
    .din     ( din       ),
    .dout    ( dout      ),
    .rom_cs  ( rom_cs    ),
    .rom_ok  ( rom_ok    )
);

jtframe_ram #(.DW(8), .AW(12)) u_ram(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( dout      ),
    .addr   ( A[11:0]   ),
    .we     ( ram && !wr_n && cpu_cen ),
    .q      ( ramq      )
);

reg [7:0] lat;
reg       y1_l, y2_l, st_wr_l;
always @(posedge clk) begin
    if( rst ) begin
        status <= 0; lat <= 0; y1_l <= 1; y2_l <= 1; st_wr_l <= 0;
    end else begin
        y1_l <= y1_irqn; y2_l <= y2_irqn;
        st_wr_l <= st_cs && !wr_n;
        if( latch_wr ) begin lat <= latch; status[3:2] <= 2'b11; end
        if( !y1_irqn && y1_l ) status[0] <= 1;
        if( !y2_irqn && y2_l ) status[1] <= 1;
        if( st_cs && !wr_n && !st_wr_l ) begin
            if( !dout[4] ) status[0] <= 0;
            if( !dout[5] ) status[1] <= 0;
            if( !dout[6] ) status[2] <= 0;
            if( !dout[7] ) status[3] <= 0;
        end
    end
end

always @(*) begin
    din = 8'hFF;
    if( rom ) din = rom_data;
    else if( ram ) din = ramq;
    else if( lat_cs ) din = lat;
    else if( y1_cs ) din = y1_dout;
    else if( y2_cs ) din = y2_dout;
    else if( st_cs ) din = { 4'd0, status };
end

jtopl u_ym1(
    .rst    ( rst        ),
    .clk    ( clk        ),
    .cen    ( cen        ),
    .din    ( dout       ),
    .addr   ( A[10]      ),
    .cs_n   ( ~y1_cs     ),
    .wr_n   ( wr_n       ),
    .dout   ( y1_dout    ),
    .irq_n  ( y1_irqn    ),
    .snd    ( ym1_raw    ),
    .sample (            )
);

always @(posedge clk) ym1 <= gwar_y8950_dac( {ym1_raw[15], ym1_raw} );

function signed [15:0] gwar_y8950_dac( input signed [16:0] v );
    reg signed [15:0] c;
    reg [14:0] m;
    reg [3:0]  drop;
    integer k;
    begin
        c = v > 17'sd32767 ? 16'sd32767 : v < -17'sd32768 ? -16'sd32768 : v[15:0];
        m = c[14:0] ^ {15{c[15]}};
        drop = 0;
        for( k=9; k<15; k=k+1 ) if( m[k] ) drop = k[3:0]-4'd8;
        gwar_y8950_dac = c & ~((16'd1 << drop) - 16'd1);
    end
endfunction

gwar_y8950 u_ym2(
    .rst      ( rst        ),
    .clk      ( clk        ),
    .cen      ( cen        ),
    .addr     ( A[10]      ),
    .cs_n     ( ~y2_cs     ),
    .wr_n     ( wr_n       ),
    .din      ( dout       ),
    .dout     ( y2_dout    ),
    .irq_n    ( y2_irqn    ),
    .rom_addr ( pcm_addr   ),
    .rom_cs   ( pcm_cs     ),
    .rom_data ( pcm_data   ),
    .rom_ok   ( pcm_ok     ),
    .snd      ( ym2        ),
    .sample   (            )
);

endmodule
