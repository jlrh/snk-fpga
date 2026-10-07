`timescale 1ns/1ps
module jtmechatt_adpcmb #(parameter AW=17, RSHIFT=1) (
    input                rst,
    input                clk,
    input                tick,
    input                wr,
    input        [ 3:0]  wreg,
    input        [ 7:0]  wdata,
    output       [ 2:0]  status,
    input                clr,
    output reg [AW-1:0]  rom_addr,
    output reg           rom_cs,
    input        [ 7:0]  rom_data,
    input                rom_ok,
    output reg signed [15:0] snd_l,
    output reg signed [15:0] snd_r
);

localparam [14:0] STEP_MIN = 15'd127;
localparam [14:0] STEP_MAX = 15'd24576;

reg  [7:0]  r0, r1, level;
reg  [15:0] start, stop, deltan, limit;

wire execute  = r0[7];
wire record   = r0[6];
wire external = r0[5];
wire repeat_f = r0[4];
wire [2:0] shift = (r1[0] || r1[1]) ? 3'd5 : 3'd2;

reg         eos, brdy, playing, int_playing;
reg         latch_pend;
reg  [23:0] curaddr;
reg  [31:0] buffer;
reg  [ 3:0] nibbles;
reg  [15:0] position;
reg  signed [15:0] acc, out, prev;
reg  [14:0] step;

assign status = { playing, brdy, eos };

wire [ 3:0] nib     = buffer[31:28];
wire [18:0] dmag    = ( {nib[2:0],1'b1} * step ) >> 3;
wire signed [17:0] sum = $signed({acc[15],acc[15],acc}) + ( nib[3] ? -$signed({1'b0,dmag[16:0]}) : $signed({1'b0,dmag[16:0]}) );
wire signed [15:0] acc_n = sum > 18'sd32767 ? 16'sd32767 : sum < -18'sd32768 ? -16'sd32768 : sum[15:0];
reg  [ 7:0] scale;
always @(*) case( nib[2:0] )
    3'd4: scale = 8'd77; 3'd5: scale = 8'd102; 3'd6: scale = 8'd128; 3'd7: scale = 8'd153;
    default: scale = 8'd57;
endcase
wire [22:0] stepm  = ( step * scale ) >> 6;
wire [14:0] step_n = stepm > STEP_MAX ? STEP_MAX : stepm < STEP_MIN ? STEP_MIN : stepm[14:0];

localparam IDLE=0, FETCH=1, FWAIT=2, OUTP=3;
reg  [1:0] st;
reg  [1:0] fwait_cnt;
wire [16:0] pos_sum   = {1'b0,position} + {1'b0,deltan};
wire [23:0] unitmask  = (24'd1 << shift) - 24'd1;
wire [23:0] latch_val = external ? {8'd0, start} << shift : 24'd0;
wire [23:0] unitaddr  = curaddr >> shift;
wire [31:0] buf_app   = buffer | ( {24'd0, rom_data} << (5'd24 - {nibbles,2'b00}) );

wire signed [33:0] mix = $signed(prev) * $signed({1'b0, 17'h10000 - {1'b0,position}}) +
                         $signed(out)  * $signed({1'b0, 1'b0, position});
wire signed [17:0] interp = mix >>> 16;
wire signed [26:0] lvl = interp * $signed({1'b0, level});
wire signed [26:0] lvs = lvl >>> (8+RSHIFT);
wire signed [15:0] lvc = lvs > 27'sd32767 ? 16'sd32767 : lvs < -27'sd32768 ? -16'sd32768 : lvs[15:0];

always @(posedge clk) begin
    if( rst ) begin
        r0 <= 0; r1 <= 0; level <= 0; start <= 0; stop <= 0; deltan <= 0; limit <= 16'hffff;
        eos <= 0; brdy <= 1; playing <= 0; int_playing <= 0; latch_pend <= 0;
        curaddr <= 0; buffer <= 0; nibbles <= 0; position <= 0;
        acc <= 0; out <= 0; prev <= 0; step <= STEP_MIN;
        st <= IDLE; rom_cs <= 0; rom_addr <= 0; snd_l <= 0; snd_r <= 0; fwait_cnt <= 0;
    end else begin
        if( clr ) begin eos <= 0; playing <= 0; end

        if( wr ) begin
            case( wreg )
                4'h0: begin
                    r0 <= wdata;
                    if( wdata[0] ) begin
                        brdy <= 1;
                        if( int_playing ) eos <= 1;
                        int_playing <= 0;
                    end else begin
                        brdy <= 1;
                        playing <= 0; int_playing <= 0;
                        latch_pend <= 1;
                        if( wdata[7] ) begin
                            buffer <= 0; nibbles <= 0; position <= 0;
                            acc <= 0; step <= STEP_MIN; out <= 0;
                            playing <= 1; int_playing <= 1; eos <= 0;
                        end
                    end
                end
                4'h1: r1 <= wdata;
                4'h2: start[ 7:0] <= wdata;
                4'h3: start[15:8] <= wdata;
                4'h4: stop [ 7:0] <= wdata;
                4'h5: stop [15:8] <= wdata;
                4'h9: deltan[ 7:0] <= wdata;
                4'hA: deltan[15:8] <= wdata;
                4'hB: level <= wdata;
                4'hC: limit[ 7:0] <= wdata;
                4'hD: limit[15:8] <= wdata;
                default:;
            endcase
        end

        case( st )
            IDLE: if( tick ) begin
                if( !execute || record || !int_playing ) begin
                    prev <= out;
                    position <= 0;
                    int_playing <= 0;
                    st <= OUTP;
                end else begin
                    position <= pos_sum[15:0];
                    if( !pos_sum[16] ) st <= OUTP;
                    else begin
                        if( nibbles != 0 ) begin
                            buffer  <= buffer << 4;
                            acc     <= acc_n;
                            step    <= step_n;
                            prev    <= out;
                            out     <= acc_n;
                            nibbles <= nibbles - 4'd1;
                            if( nibbles == 4'd1 ) begin
                                acc  <= 0;
                                step <= STEP_MIN;
                                eos  <= 1;
                                if( !repeat_f ) int_playing <= 0;
                            end
                        end
                        st <= FETCH;
                    end
                end
            end
            FETCH: begin

                if( int_playing && nibbles < 4'd3 ) begin
                    if( latch_pend ) latch_pend <= 0;
                    if( !external ) begin
                        if( latch_pend ) curaddr <= latch_val;
                        brdy <= 1;
                        st <= OUTP;
                    end else begin
                        if( latch_pend ) begin
                            curaddr  <= latch_val;
                            rom_addr <= latch_val[AW-1:0];
                        end else begin
                            rom_addr <= curaddr[AW-1:0];
                        end
                        rom_cs <= 1;
                        fwait_cnt <= 2'd2;
                        st <= FWAIT;
                    end
                end else st <= OUTP;
            end
            FWAIT: begin
                if( fwait_cnt != 0 ) fwait_cnt <= fwait_cnt - 2'd1;
                else if( rom_ok ) begin
                    rom_cs <= 0;
                    buffer  <= buf_app;
                    nibbles <= nibbles + 4'd2;

                    if( (curaddr & unitmask) == unitmask && unitaddr == {8'd0,stop} ) begin

                        buffer  <= buf_app << 12;
                        nibbles <= (nibbles + 4'd2) > 4'd3 ? nibbles + 4'd2 - 4'd3 : 4'd0;
                        if( repeat_f ) curaddr <= latch_val;
                    end else if( (curaddr & unitmask) == unitmask && unitaddr == {8'd0,limit} ) begin
                        curaddr <= 0;
                    end else begin
                        curaddr <= curaddr + 24'd1;
                    end
                    st <= OUTP;
                end
            end
            OUTP: begin
                snd_l <= r1[7] ? lvc : 16'sd0;
                snd_r <= r1[6] ? lvc : 16'sd0;
                st  <= IDLE;
            end
        endcase
    end
end

endmodule
