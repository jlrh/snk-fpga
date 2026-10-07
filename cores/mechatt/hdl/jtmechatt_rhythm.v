`timescale 1ns/1ps
module jtmechatt_rhythm(
    input                 rst,
    input                 clk,
    input                 tick,
    input                 half,
    input                 wr,
    input         [ 3:0]  wreg,
    input         [ 7:0]  wdata,
    output reg    [12:0]  rom_addr,
    output reg            rom_cs,
    input         [ 7:0]  rom_data,
    input                 rom_ok,
    output reg signed [15:0] snd_l,
    output reg signed [15:0] snd_r
);

function [12:0] istart( input [2:0] c );
    case( c ) 3'd0: istart=13'h0000; 3'd1: istart=13'h01c0; 3'd2: istart=13'h0440;
              3'd3: istart=13'h1b80; 3'd4: istart=13'h1d00; default: istart=13'h1f80; endcase
endfunction
function [13:0] iend1( input [2:0] c );
    case( c ) 3'd0: iend1=14'h01c0; 3'd1: iend1=14'h0440; 3'd2: iend1=14'h1b80;
              3'd3: iend1=14'h1d00; 3'd4: iend1=14'h1f80; default: iend1=14'h2000; endcase
endfunction
function [10:0] steps( input [5:0] i );
    case( i )
     0:steps=16;  1:steps=17;  2:steps=19;  3:steps=21;  4:steps=23;  5:steps=25;  6:steps=28;
     7:steps=31;  8:steps=34;  9:steps=37; 10:steps=41; 11:steps=45; 12:steps=50; 13:steps=55;
    14:steps=60; 15:steps=66; 16:steps=73; 17:steps=80; 18:steps=88; 19:steps=97; 20:steps=107;
    21:steps=118;22:steps=130;23:steps=143;24:steps=157;25:steps=173;26:steps=190;27:steps=209;
    28:steps=230;29:steps=253;30:steps=279;31:steps=307;32:steps=337;33:steps=371;34:steps=408;
    35:steps=449;36:steps=494;37:steps=544;38:steps=598;39:steps=658;40:steps=724;41:steps=796;
    42:steps=876;43:steps=963;44:steps=1060;45:steps=1166;46:steps=1282;47:steps=1411;default:steps=1552;
    endcase
endfunction

reg  [ 5:0] tl;
reg  [ 7:0] lracl [0:5];
reg  [ 5:0] playing, nib;
reg  [ 7:0] curbyte [0:5];
reg  [13:0] curaddr [0:5];
reg  [11:0] acc     [0:5];
reg  [ 5:0] stepi   [0:5];

integer k;

localparam [1:0] IDLE=0, CH=1, FETCH=2, SUM=3;
reg  [1:0]  st;
reg  [2:0]  c;
reg         hl;
reg  signed [17:0] accl, accr;

wire [3:0]  d      = nib[c] ? curbyte[c][3:0] : rom_data[7:4];
wire [15:0] dmul   = {12'd0, d[2:0], 1'b1} * {5'd0, steps(stepi[c])};
wire [11:0] delta  = dmul[14:3];
wire [11:0] accn   = d[3] ? acc[c] - delta : acc[c] + delta;
reg  signed [6:0] sinc;
always @* case( d[2:0] ) 3'd4: sinc=2; 3'd5: sinc=5; 3'd6: sinc=7; 3'd7: sinc=9; default: sinc=-1; endcase
wire signed [7:0] stepn = $signed({2'b0, stepi[c]}) + sinc;
wire [5:0]  stepc  = stepn < 0 ? 6'd0 : stepn > 48 ? 6'd48 : stepn[5:0];

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        tl <= 0; playing <= 0; nib <= 0; st <= IDLE; c <= 0; hl <= 0; rom_cs <= 0; rom_addr <= 0;
        accl <= 0; accr <= 0;
        for( k=0; k<6; k=k+1 ) begin
            lracl[k] <= 8'hdf; curbyte[k] <= 0; curaddr[k] <= 0; acc[k] <= 0; stepi[k] <= 0;
        end
    end else begin
        case( st )
            IDLE: if( tick ) begin c <= 0; hl <= half; accl <= 0; accr <= 0; st <= CH; end
            CH: begin
                if( (hl && c >= 3'd4) || !playing[c] ) begin
                    if( !playing[c] ) acc[c] <= 0;
                    st <= SUM;
                end else if( !nib[c] ) begin
                    if( curaddr[c] == iend1(c) ) begin
                        playing[c] <= 0; acc[c] <= 0; st <= SUM;
                    end else begin
                        rom_addr <= curaddr[c][12:0]; rom_cs <= 1; st <= FETCH;
                    end
                end else begin
                    acc[c] <= accn; stepi[c] <= stepc; nib[c] <= 0; st <= SUM;
                end
            end
            FETCH: if( rom_ok ) begin
                rom_cs <= 0;
                curbyte[c] <= rom_data; curaddr[c] <= curaddr[c] + 1'd1;
                acc[c] <= accn; stepi[c] <= stepc; nib[c] <= 1; st <= SUM;
            end
            SUM: begin

                if( c == 3'd5 ) st <= IDLE; else begin c <= c + 1'd1; st <= CH; end
            end
        endcase

        if( wr ) case( wreg )
            4'h0: for( k=0; k<6; k=k+1 ) if( wdata[k] ) begin
                    playing[k] <= ~wdata[7];
                    if( !wdata[7] ) begin
                        curaddr[k] <= {1'b0, istart(k[2:0])}; nib[k] <= 0; curbyte[k] <= 0; acc[k] <= 0; stepi[k] <= 0;
                    end
                  end
            4'h1: tl <= wdata[5:0];
            4'h8, 4'h9, 4'ha, 4'hb, 4'hc, 4'hd: lracl[wreg - 4'h8] <= wdata;
            default:;
        endcase
    end
end

reg [2:0] oc; reg osum; reg signed [17:0] ol, orr; reg tick_l;
wire [6:0]  ovol   = {2'b0, lracl[oc][4:0] ^ 5'h1f} + {1'b0, tl ^ 6'h3f};
wire signed [4:0]  omul = 5'd15 - {2'b0, ovol[2:0]};
wire [3:0]  oshift = 4'd5 + {1'b0, ovol[5:3]};
wire signed [20:0] oprod = $signed({acc[oc], 4'd0}) * omul;
wire signed [20:0] oshf  = oprod >>> oshift;
wire signed [15:0] oval  = { oshf[15:2], 2'b00 };
always @(posedge clk, posedge rst) begin
    if( rst ) begin oc <= 0; osum <= 0; ol <= 0; orr <= 0; tick_l <= 0; snd_l <= 0; snd_r <= 0; end
    else begin
        tick_l <= st == SUM && c == 3'd5;
        if( tick_l ) begin oc <= 0; osum <= 1; ol <= 0; orr <= 0; end
        else if( osum ) begin
            if( ovol < 7'd63 ) begin
                if( lracl[oc][7] ) ol  <= ol  + oval;
                if( lracl[oc][6] ) orr <= orr + oval;
            end
            if( oc == 3'd5 ) begin
                osum <= 0;
                snd_l <= (ovol < 7'd63 && lracl[oc][7]) ? ol[15:0] + oval : ol[15:0];
                snd_r <= (ovol < 7'd63 && lracl[oc][6]) ? orr[15:0] + oval : orr[15:0];
            end else oc <= oc + 1'd1;
        end
    end
end

endmodule
