`timescale 1ns/1ps
module jtbbusters_tilelayer #(parameter
    TILE16 = 1,
    COLW   = 7,
    VAW    = 12,
    RAW    = 17
)(
    input                 rst,
    input                 clk,
    input                 start,
    input           [8:0] vr,
    input          [15:0] scrx, scry,
    input                 page,

    output reg  [VAW-1:0] vram_addr,
    input          [15:0] vram_q,

    output reg  [RAW-1:0] rom_addr,
    output reg            rom_cs,
    input          [31:0] rom_data,
    input                 rom_ok,

    output reg      [7:0] lb_addr,
    output reg      [7:0] lb_data,
    output reg            lb_we,
    output reg            busy
);

localparam NTILES = TILE16 ? 17 : 32;
localparam [2:0] IDLE=0, MAP=1, MAPW=2, ROM=3, DRAW=4;

reg  [2:0] st;
reg  [5:0] ti;
wire [7:0] ti8 = {2'd0, ti};
reg        half;
reg  [2:0] k;
reg [11:0] code;
reg  [3:0] color;
reg [31:0] gfx;
reg  [8:0] Y;
reg [11:0] X0w;
wire [3:0] fine = TILE16 ? X0w[3:0] : 4'd0;
reg  [9:0] px;

wire [3:0] pix = k[0] ? gfx[ {k[2:1], 3'd0} +: 4 ] : gfx[ {k[2:1], 3'd4} +: 4 ];

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st <= IDLE; busy <= 0; rom_cs <= 0; lb_we <= 0;
        vram_addr <= 0; rom_addr <= 0; lb_addr <= 0; lb_data <= 0;
        ti <= 0; half <= 0; k <= 0; code <= 0; color <= 0; gfx <= 0; Y <= 0; X0w <= 0; px <= 0;
    end else begin
        lb_we <= 0;
        case( st )
            IDLE: if( start ) begin
                busy <= 1;
                ti   <= 0;
                half <= 0;
                if( TILE16 ) begin
                    Y   <= vr + scry[8:0];
                    X0w <= scrx[11:0] & ((12'd1 << (COLW+4)) - 12'd1);
                end else begin
                    Y   <= vr;
                    X0w <= 0;
                end
                st <= MAP;
            end
            MAP: begin
                if( TILE16 ) begin : pf
                    reg [COLW-1:0] col;
                    col = X0w[COLW+3:4] + ti8[COLW-1:0];
                    vram_addr <= { col, Y[8:4] };
                end else begin
                    vram_addr <= { page, Y[7:3], ti[4:0] };
                end
                st <= MAPW;
            end
            MAPW: st <= ROM;
            ROM: begin
                if( !rom_cs ) begin
                    code  <= vram_q[11:0];
                    color <= vram_q[15:12];
                    rom_addr <= TILE16 ? { vram_q[11:0], half, Y[3:0] } : { vram_q[11:0], Y[2:0] };
                    rom_cs   <= 1;
                end else if( rom_ok ) begin
                    rom_cs <= 0;
                    gfx    <= rom_data;
                    k      <= 0;
                    px     <= TILE16 ? {1'b0, ti[4:0], half, 3'd0} - {6'd0, fine} : {2'd0, ti[4:0], 3'd0};
                    st     <= DRAW;
                end
            end
            DRAW: begin

                lb_addr <= px[7:0];
                lb_data <= { color, pix };
                lb_we   <= ~px[9] & ~px[8];
                px      <= px + 10'd1;
                k       <= k + 3'd1;
                if( k == 3'd7 ) begin
                    if( TILE16 && !half ) begin
                        half <= 1;
                        rom_addr <= { code, 1'b1, Y[3:0] };
                        rom_cs   <= 1;
                        st       <= ROM;
                    end else begin
                        half <= 0;
                        if( ti == NTILES-1 ) begin
                            st   <= IDLE;
                            busy <= 0;
                        end else begin
                            ti <= ti + 6'd1;
                            st <= MAP;
                        end
                    end
                end
            end
            default: st <= IDLE;
        endcase
    end
end

endmodule
