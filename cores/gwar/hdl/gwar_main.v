module gwar_main(
    input             rst,
    input             clk,
    input             cen_a,
    input             cen_b,
    input             LVBL,

    output     [15:0] main_addr,
    output            main_cs,
    input      [ 7:0] main_data,
    input             main_ok,
    output     [15:0] sub_addr,
    output            sub_cs,
    input      [ 7:0] sub_data,
    input             sub_ok,

    input      [ 7:0] in0,
    input      [ 3:0] joy1, joy2,
    input      [ 7:0] in3,
    input      [ 7:0] dsw1, dsw2,
    input      [ 3:0] rot1, rot2,

    output reg [ 7:0] snd_latch,
    output reg        snd_wr,
    input             snd_busy,

    output reg [ 8:0] bg_scrollx, bg_scrolly,
    output reg [ 8:0] sp16_scrollx, sp16_scrolly,
    output reg [ 8:0] sp32_scrollx, sp32_scrolly,
    output reg [ 7:0] split,
    output reg [ 7:0] txbank,
    output reg        flip,

    input      [10:0] vbg_addr,
    output     [ 7:0] vbg_data,
    input      [10:0] vtx_addr,
    output     [ 7:0] vtx_data,
    input      [ 6:0] vspr_addr,
    output     [31:0] vspr_data,

    output     [15:0] dbg_a, dbg_b
);

wire [15:0] a_A;
wire [ 7:0] a_dout;
reg  [ 7:0] a_din;
wire        a_mreq_n, a_rd_n, a_wr_n, a_rfsh_n, a_m1_n, a_iorq_n, a_cen;
reg         nmi_a, nmi_b;

wire a_mem   = !a_mreq_n && a_rfsh_n;
wire a_rom   = a_mem && a_A[15:14] != 2'b11;
wire a_io    = a_mem && a_A[15:12] == 4'hC;
wire a_ram   = a_mem && a_A[15:12] >= 4'hD;
wire a_rd    = a_cen && !a_rd_n;
wire a_wr    = a_cen && !a_wr_n;

assign main_addr = a_A;
assign main_cs   = a_rom;

jtframe_z80_romwait #(.CLR_INT(1)) u_cpua(
    .rst_n   ( ~rst      ),
    .clk     ( clk       ),
    .cen     ( cen_a     ),
    .cpu_cen ( a_cen     ),
    .int_n   ( LVBL      ),
    .nmi_n   ( ~nmi_a    ),
    .busrq_n ( 1'b1      ),
    .m1_n    ( a_m1_n    ),
    .mreq_n  ( a_mreq_n  ),
    .iorq_n  ( a_iorq_n  ),
    .rd_n    ( a_rd_n    ),
    .wr_n    ( a_wr_n    ),
    .rfsh_n  ( a_rfsh_n  ),
    .halt_n  (           ),
    .busak_n (           ),
    .A       ( a_A       ),
    .din     ( a_din     ),
    .dout    ( a_dout    ),
    .rom_cs  ( main_cs   ),
    .rom_ok  ( main_ok   )
);

wire [15:0] b_A;
wire [ 7:0] b_dout;
reg  [ 7:0] b_din;
wire        b_mreq_n, b_rd_n, b_wr_n, b_rfsh_n, b_m1_n, b_iorq_n, b_cen;

wire b_mem   = !b_mreq_n && b_rfsh_n;
wire b_rom   = b_mem && b_A[15:14] != 2'b11;
wire b_io    = b_mem && b_A[15:12] == 4'hC;
wire b_ram   = b_mem && b_A[15:12] >= 4'hD;
wire b_rd    = b_cen && !b_rd_n;
wire b_wr    = b_cen && !b_wr_n;

assign sub_addr = b_A;
assign sub_cs   = b_rom;

jtframe_z80_romwait #(.CLR_INT(1)) u_cpub(
    .rst_n   ( ~rst      ),
    .clk     ( clk       ),
    .cen     ( cen_b     ),
    .cpu_cen ( b_cen     ),
    .int_n   ( LVBL      ),
    .nmi_n   ( ~nmi_b    ),
    .busrq_n ( 1'b1      ),
    .m1_n    ( b_m1_n    ),
    .mreq_n  ( b_mreq_n  ),
    .iorq_n  ( b_iorq_n  ),
    .rd_n    ( b_rd_n    ),
    .wr_n    ( b_wr_n    ),
    .rfsh_n  ( b_rfsh_n  ),
    .halt_n  (           ),
    .busak_n (           ),
    .A       ( b_A       ),
    .din     ( b_din     ),
    .dout    ( b_dout    ),
    .rom_cs  ( sub_cs    ),
    .rom_ok  ( sub_ok    )
);

assign dbg_a = a_A;
assign dbg_b = b_A;

wire [7:0] a_ramq, b_ramq;

jtframe_dual_ram #(.DW(8), .AW(14)) u_shared(
    .clk0   ( clk          ),
    .data0  ( a_dout       ),
    .addr0  ( a_A[13:0]    ),
    .we0    ( a_ram & a_wr ),
    .q0     ( a_ramq       ),
    .clk1   ( clk          ),
    .data1  ( b_dout       ),
    .addr1  ( b_A[13:0]    ),
    .we1    ( b_ram & b_wr ),
    .q1     ( b_ramq       )
);

wire        sh_wa  = a_ram & a_wr;
wire        sh_wb  = b_ram & b_wr;
wire [15:0] sh_A   = sh_wa ? a_A    : b_A;
wire [ 7:0] sh_d   = sh_wa ? a_dout : b_dout;
wire        sh_we  = sh_wa | sh_wb;
wire        bg_we  = sh_we && sh_A[15:11] == 5'b1101_0;
wire        tx_we  = sh_we && sh_A[15:11] == 5'b1111_1;
wire        spr_we = sh_we && sh_A[15:12] == 4'hE && sh_A[10:8] == 3'd0;

jtframe_dual_ram #(.DW(8), .AW(11)) u_bgv(
    .clk0( clk ), .data0( sh_d ), .addr0( sh_A[10:0] ), .we0( bg_we ), .q0(),
    .clk1( clk ), .data1( 8'd0 ), .addr1( vbg_addr ), .we1( 1'b0 ), .q1( vbg_data ) );

jtframe_dual_ram #(.DW(8), .AW(11)) u_txv(
    .clk0( clk ), .data0( sh_d ), .addr0( sh_A[10:0] ), .we0( tx_we ), .q0(),
    .clk1( clk ), .data1( 8'd0 ), .addr1( vtx_addr ), .we1( 1'b0 ), .q1( vtx_data ) );

genvar lane;
generate for( lane=0; lane<4; lane=lane+1 ) begin : g_spr
    jtframe_dual_ram #(.DW(8), .AW(7)) u_sprv(
        .clk0( clk ), .data0( sh_d ), .addr0( { sh_A[11], sh_A[7:2] } ),
        .we0( spr_we && sh_A[1:0] == lane ), .q0(),
        .clk1( clk ), .data1( 8'd0 ), .addr1( vspr_addr ), .we1( 1'b0 ), .q1( vspr_data[lane*8 +: 8] ) );
end endgenerate

reg  [3:0] last1, last2;
reg  [2:0] cp1, cp2;
reg        rd_l;
wire       in1_rd = a_io && !a_rd_n && a_A[11:8] == 4'h1;
wire       in2_rd = a_io && !a_rd_n && a_A[11:8] == 4'h2;
wire [3:0] rv1 = ( ((last1 == 4'd5 && rot1 == 4'd6) || (last1 == 4'd6 && rot1 == 4'd5)) && cp1 == 0 ) ? 4'hF : rot1;
wire [3:0] rv2 = ( ((last2 == 4'd5 && rot2 == 4'd6) || (last2 == 4'd6 && rot2 == 4'd5)) && cp2 == 0 ) ? 4'hF : rot2;
reg  [3:0] rv1_l, rv2_l;

always @(posedge clk) begin
    if( rst ) begin
        last1 <= 0; last2 <= 0; cp1 <= 0; cp2 <= 0; rd_l <= 0; rv1_l <= 0; rv2_l <= 0;
    end else begin
        rd_l <= !a_rd_n && a_io;

        if( (in1_rd || in2_rd) && !rd_l ) begin
            if( in1_rd ) begin
                rv1_l <= rv1;
                if( (last1 == 4'd5 && rot1 == 4'd6) || (last1 == 4'd6 && rot1 == 4'd5) ) cp1 <= cp1 + 3'd1;
                last1 <= rv1;
            end
            if( in2_rd ) begin
                rv2_l <= rv2;
                if( (last2 == 4'd5 && rot2 == 4'd6) || (last2 == 4'd6 && rot2 == 4'd5) ) cp2 <= cp2 + 3'd1;
                last2 <= rv2;
            end
        end
    end
end

always @(posedge clk) begin
    if( rst ) begin
        bg_scrollx <= 0; bg_scrolly <= 0; sp16_scrollx <= 0; sp16_scrolly <= 0;
        sp32_scrollx <= 0; sp32_scrolly <= 0; split <= 0; txbank <= 0; flip <= 0;
        snd_latch <= 0; snd_wr <= 0;
        nmi_a <= 0; nmi_b <= 0;
    end else begin
        snd_wr <= 0;

        if( a_io && a_rd ) begin
            if( a_A[11:8] == 4'h7 ) nmi_b <= 1;
        end
        if( a_io && a_wr ) begin
            case( a_A[11:8] )
                4'h4: begin snd_latch <= a_dout; snd_wr <= 1; end
                4'h7: nmi_a <= 0;
                4'h8: case( a_A[7:6] )
                        2'd0: bg_scrolly[7:0] <= a_dout;
                        2'd1: bg_scrollx[7:0] <= a_dout;
                        2'd2: begin
                            sp32_scrollx[8] <= a_dout[7];
                            sp16_scrollx[8] <= a_dout[6];
                            sp32_scrolly[8] <= a_dout[5];
                            sp16_scrolly[8] <= a_dout[4];
                            flip            <= a_dout[2];
                            bg_scrollx[8]   <= a_dout[1];
                            bg_scrolly[8]   <= a_dout[0];
                        end
                        2'd3: txbank <= a_dout;
                      endcase
                4'h9: case( a_A[7:6] )
                        2'd0: sp16_scrolly[7:0] <= a_dout;
                        2'd1: sp16_scrollx[7:0] <= a_dout;
                        2'd2: sp32_scrolly[7:0] <= a_dout;
                        2'd3: sp32_scrollx[7:0] <= a_dout;
                      endcase
                4'hA: if( a_A[7:6] == 2'd3 ) split <= a_dout;
                default:;
            endcase
        end

        if( b_io && b_rd && b_A[11:8] == 4'h0 ) nmi_a <= 1;
        if( b_io && b_wr ) begin
            if( b_A[11:8] == 4'h0 ) nmi_b <= 0;
            if( b_A[11:8] == 4'h8 && b_A[7:6] == 2'd3 ) txbank <= b_dout;
        end
    end
end

always @(*) begin
    a_din = 8'hFF;
    if( a_rom ) a_din = main_data;
    else if( a_ram ) a_din = a_ramq;
    else if( a_io ) case( a_A[11:8] )
        4'h0: a_din = { in0[7:1], snd_busy };
        4'h1: a_din = { rv1_l, joy1 };
        4'h2: a_din = { rv2_l, joy2 };
        4'h3: a_din = in3;
        4'h5: a_din = dsw1;
        4'h6: a_din = dsw2;
        default: a_din = 8'hFF;
    endcase
end

always @(*) begin
    b_din = 8'hFF;
    if( b_rom ) b_din = sub_data;
    else if( b_ram ) b_din = b_ramq;
end

endmodule
