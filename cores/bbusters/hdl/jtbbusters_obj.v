`timescale 1ns/1ps
module jtbbusters_obj(
    input             rst,
    input             clk,
    input             LVBL,
    input             start,
    input       [8:0] vr,

    output reg [11:1] ram_addr,
    input      [15:0] ram_q,

    output reg        scl_req,
    output reg [15:0] scl_addr,
    input             scl_ack,
    input       [7:0] scl_data,

    output reg [20:2] rom_addr,
    output reg        rom_cs,
    input      [31:0] rom_data,
    input             rom_ok,

    output reg  [7:0] lb_addr,
    output reg  [7:0] lb_data,
    output reg        lb_we,
    output reg        busy
);

reg        lvbl_l, copying, cp_we;
reg [11:0] cp_cnt;
reg [10:0] cp_waddr;
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        lvbl_l <= 1; copying <= 0; cp_cnt <= 0; cp_we <= 0; cp_waddr <= 0;
    end else begin
        lvbl_l <= LVBL;
        cp_we  <= copying;
        cp_waddr <= cp_cnt[10:0];
        if( lvbl_l & ~LVBL ) begin copying <= 1; cp_cnt <= 0; end
        else if( copying ) begin
            cp_cnt <= cp_cnt + 12'd1;
            if( cp_cnt == 12'd2047 ) copying <= 0;
        end
    end
end

reg  [8:0] ent;
reg  [8:0] ecur;
wire [15:0] b_col, b_spr, b_x, b_y;
jtframe_dual_ram #(.DW(16),.AW(9)) u_bcol(.clk0(clk),.data0(ram_q),.addr0(cp_waddr[10:2]),.we0(cp_we && cp_waddr[1:0]==2'd0),.q0(),
                                           .clk1(clk),.data1(16'd0),.addr1(ent),.we1(1'b0),.q1(b_col));
jtframe_dual_ram #(.DW(16),.AW(9)) u_bspr(.clk0(clk),.data0(ram_q),.addr0(cp_waddr[10:2]),.we0(cp_we && cp_waddr[1:0]==2'd1),.q0(),
                                           .clk1(clk),.data1(16'd0),.addr1(ent),.we1(1'b0),.q1(b_spr));
jtframe_dual_ram #(.DW(16),.AW(9)) u_bx  (.clk0(clk),.data0(ram_q),.addr0(cp_waddr[10:2]),.we0(cp_we && cp_waddr[1:0]==2'd2),.q0(),
                                           .clk1(clk),.data1(16'd0),.addr1(ent),.we1(1'b0),.q1(b_x));
jtframe_dual_ram #(.DW(16),.AW(9)) u_by  (.clk0(clk),.data0(ram_q),.addr0(cp_waddr[10:2]),.we0(cp_we && cp_waddr[1:0]==2'd3),.q0(),
                                           .clk1(clk),.data1(16'd0),.addr1(ent),.we1(1'b0),.q1(b_y));
always @* ram_addr = cp_cnt[10:0];

wire [1:0]  blk   = b_col[9:8];
wire        fy    = b_col[10];
wire        fx    = b_col[11];
wire [3:0]  pcol  = b_col[15:12];
reg  [5:0]  scale;
reg  [7:0]  size;
reg [15:0]  tbase;
always @* begin
    case( blk )
        2'd0: begin scale = {3'd0, b_col[2:0]}; size = 8'd16;  tbase = 16'h387f; end
        2'd1: begin scale = {2'd0, b_col[3:0]}; size = 8'd32;  tbase = 16'h707f; end
        2'd2: begin scale = {1'd0, b_col[4:0]}; size = 8'd64;  tbase = 16'ha07f; end
        default: begin scale = b_col[5:0];      size = 8'd128; tbase = 16'hc07f; end
    endcase
end
wire [7:0]  lines = size - {2'd0, scale};
wire        hack  = (b_col == 16'h00f7 || b_col == 16'hffff || b_col == 16'h43f9) &&
                    (b_spr == 16'h3fff || b_spr == 16'hffff || b_spr == 16'h0001);

wire signed [15:0] ys = b_y;
wire [15:0] yeff = (ys > 16'sd320 || ys < -16'sd256) ? {7'd0, b_y[8:0]} : b_y;
wire [15:0] jrow = {7'd0, vr} - yeff;
wire        hit  = ~hack && ~jrow[15] && (jrow < {8'd0, lines});

wire [8:0]  xeff = b_x[9] ? {1'b1, b_x[7:0]} : b_x[8:0];

localparam [2:0] IDLE=0, RD=1, EVAL=2, SCL=3, SCLW=4, DRAWL=5, FLUSH=6;
reg        nl_ok;
reg  [2:0]  st;
reg  [7:0]  d_size, d_lines, sx;
reg  [1:0]  d_blk;
reg         d_fx, d_fy;
reg  [3:0]  d_col;
reg [13:0]  d_spr;
reg  [8:0]  d_x;
reg  [7:0]  srcline;
reg [23:0]  xidx, xinc;

reg  [4:0]  f_chunk, n_chunks;
reg         have_next, drawing;
reg [31:0]  nxt, cur;
reg  [2:0]  k;

function [13:0] tile_of( input [13:0] spr, input [7:0] dx, input [7:0] dy, input [1:0] b );
    reg [13:0] c;
    begin
        c = 0;
        if( b >= 2'd1 ) begin c = c + (dy[4] ? 14'd2  : 14'd0) + (dx[4] ? 14'd1  : 14'd0); end
        if( b >= 2'd2 ) begin c = c + (dy[5] ? 14'd8  : 14'd0) + (dx[5] ? 14'd4  : 14'd0); end
        if( b == 2'd3 ) begin c = c + (dy[6] ? 14'd32 : 14'd0) + (dx[6] ? 14'd16 : 14'd0); end
        tile_of = spr + c;
    end
endfunction

wire [7:0]  f_sx   = { f_chunk, 3'd0 };
wire [13:0] f_tile = tile_of( d_spr, f_sx, srcline, d_blk );

wire [20:2] f_addr = { f_tile, srcline[3], f_sx[3], srcline[2:0] };

wire [7:0] R0 = cur[15:8], R1 = cur[7:0], R2 = cur[31:24], R3 = cur[23:16];
wire [7:0] Ra = k[2] ? R2 : R0;
wire [7:0] Rb = k[2] ? R3 : R1;
wire [1:0] kx = k[1:0];
wire [3:0] pen = { Ra[3'd7 - {1'b0,kx}], Ra[3'd3 - {1'b0,kx}], Rb[3'd7 - {1'b0,kx}], Rb[3'd3 - {1'b0,kx}] };
wire [8:0] dest = d_x + {xidx[23], xidx[23:16]};

`ifdef SIMULATION

integer ovf = 0, maxclk = 0, clks = 0, fr = 0;
integer lat = 0, lat_max = 0, lat_n = 0, lat_sum = 0; reg cs_l = 0, lvbl_ll = 1;
always @(posedge clk) begin
    if( start ) begin
        if( st != IDLE ) ovf = ovf + 1;
        clks = 0;
    end else if( busy ) begin clks = clks + 1; if( clks > maxclk ) maxclk = clks; end
    cs_l <= rom_cs;
    if( rom_cs && !cs_l ) lat = 0; else if( rom_cs ) lat = lat + 1;
    if( rom_cs && rom_ok ) begin lat_n = lat_n + 1; lat_sum = lat_sum + lat; if( lat > lat_max ) lat_max = lat; end
    lvbl_ll <= LVBL;
    if( lvbl_ll && !LVBL ) begin
        $display("OBJ_CUADRO %0d ovf=%0d max_clk_linea=%0d lat_n=%0d lat_media=%0d lat_max=%0d", fr, ovf, maxclk,
                 lat_n, lat_n ? lat_sum/lat_n : 0, lat_max);
        fr = fr + 1; ovf = 0; maxclk = 0; lat_n = 0; lat_sum = 0; lat_max = 0;
    end
end
integer trline = -1;
initial if( !$value$plusargs("objtrace=%d", trline) ) trline = -1;
always @(posedge clk) begin
    if( vr == trline[8:0] && st == EVAL && hit ) $display("OBJTR ent=%0d x=%0d size=%0d j=%0d", ecur, xeff, size, jrow);
    if( vr == trline[8:0] && lb_we ) $display("OBJTRW x=%0d d=%02x", lb_addr, lb_data);
end
`endif

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st <= IDLE; busy <= 0; ent <= 0; ecur <= 0; rom_cs <= 0; lb_we <= 0; scl_req <= 0;
        have_next <= 0; drawing <= 0; f_chunk <= 0; n_chunks <= 0; sx <= 0; k <= 0;
        scl_addr <= 0; rom_addr <= 0; lb_addr <= 0; lb_data <= 0;
        d_size <= 0; d_lines <= 0; d_blk <= 0; d_fx <= 0; d_fy <= 0; d_col <= 0; d_spr <= 0; d_x <= 0;
        srcline <= 0; xidx <= 0; xinc <= 0; nxt <= 0; cur <= 0; nl_ok <= 0;
    end else begin
        lb_we <= 0;
        if( start ) begin

            scl_req <= 0; have_next <= 0; drawing <= 0;
            busy  <= vr >= 9'd16 && vr < 9'd240;
            nl_ok <= vr >= 9'd16 && vr < 9'd240;
            ent   <= 0;
            if( rom_cs && !rom_ok ) st <= FLUSH;
            else begin
                rom_cs <= 0;
                st <= (vr >= 9'd16 && vr < 9'd240) ? RD : IDLE;
            end
        end else
        case( st )
            IDLE:;
            FLUSH: if( rom_ok ) begin rom_cs <= 0; st <= nl_ok ? RD : IDLE; end

            RD: begin ecur <= ent; ent <= ent + 9'd1; st <= EVAL; end
            EVAL: begin
                if( hit ) begin
                    d_size  <= size;  d_lines <= lines; d_blk <= blk;
                    d_fx <= fx; d_fy <= fy; d_col <= pcol;
                    d_spr <= b_spr[13:0]; d_x <= xeff;
                    scl_addr <= tbase + {3'd0, scale, 7'd0} - jrow;
                    scl_req  <= 1;

                    case( blk )
                        2'd0: xinc <= {lines, 12'd0} ;
                        2'd1: xinc <= {1'b0, lines, 11'd0};
                        2'd2: xinc <= {2'b0, lines, 10'd0};
                        default: xinc <= {3'b0, lines, 9'd0};
                    endcase
                    xidx <= fx ? { lines - 8'd1, 16'd0 } : 24'd0;
                    st <= SCL;
                end else if( ecur == 9'd511 ) begin
                    st <= IDLE; busy <= 0;
                end else begin
                    ecur <= ent; ent <= ent + 9'd1;
                end
            end
            SCL: if( scl_ack ) begin scl_req <= 0; st <= SCLW; end
            SCLW: begin
                srcline   <= d_fy ? scl_data : d_size - scl_data - 8'd1;
                f_chunk   <= 0;
                n_chunks  <= d_size[7:3];
                have_next <= 0; drawing <= 0; sx <= 0; k <= 0;
                st <= DRAWL;
            end
            DRAWL: begin

                if( !have_next && f_chunk != n_chunks ) begin
                    if( !rom_cs ) begin
                        rom_addr <= f_addr; rom_cs <= 1;
                    end else if( rom_ok ) begin
                        rom_cs <= 0; nxt <= rom_data; have_next <= 1; f_chunk <= f_chunk + 5'd1;
                    end
                end

                if( drawing ) begin
                    lb_addr <= dest[7:0];
                    lb_data <= { d_col, pen };
                    lb_we   <= pen != 4'hf && !dest[8];
                    xidx    <= d_fx ? xidx - xinc : xidx + xinc;
                    sx      <= sx + 8'd1;
                    k       <= k + 3'd1;
                    if( k == 3'd7 ) begin
                        drawing <= 0;
                        if( sx == d_size - 8'd1 ) begin
                            if( ecur == 9'd511 ) begin st <= IDLE; busy <= 0; end
                            else begin ent <= ecur + 9'd1; st <= RD; end
                        end
                    end
                end else if( have_next ) begin
                    cur <= nxt; have_next <= 0; drawing <= 1; k <= 0;
                end
            end
            default: st <= IDLE;
        endcase
    end
end

endmodule
