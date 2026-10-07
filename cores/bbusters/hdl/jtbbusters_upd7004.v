`timescale 1ns/1ps
module jtbbusters_upd7004(
    input            rst,
    input            clk,
    input            offset,
    input            rd,
    input            wr,
    input      [7:0] din,
    output reg [7:0] dout,
    output reg       eoc_ff,
    input      [9:0] ch0, ch1, ch2, ch3, ch4, ch5, ch6, ch7
);

localparam IDLE=2'd0, START=2'd1, CONV=2'd2;

reg  [1:0] st;
reg  [2:0] addr;
reg  [3:0] div;
reg  [9:0] sar;
reg [13:0] cnt;

wire [13:0] per = 14'd12 * {10'd0, div};

reg [9:0] sel;
always @* case( addr )
    3'd0: sel = ch0; 3'd1: sel = ch1; 3'd2: sel = ch2; 3'd3: sel = ch3;
    3'd4: sel = ch4; 3'd5: sel = ch5; 3'd6: sel = ch6; default: sel = ch7;
endcase

always @* dout = offset ? sar[9:2] : { sar[1:0], 6'd0 };

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st <= IDLE; addr <= 0; div <= 4'd1; sar <= 10'h3ff; cnt <= 0; eoc_ff <= 0;
    end else begin
        if( rd ) eoc_ff <= 0;
        case( st )
            START: if( cnt == 0 ) begin
                    sar <= sel;
                    cnt <= 14'd100 * per - 14'd1;
                    st  <= CONV;
                end else cnt <= cnt - 1'd1;
            CONV: if( cnt == 0 ) begin
                    eoc_ff <= 1;
                    st     <= IDLE;
                end else cnt <= cnt - 1'd1;
            default:;
        endcase
        if( wr ) begin
            if( !offset ) begin
                addr <= din[2:0];
                st   <= START;
                cnt  <= per - 14'd1;
            end else begin
                div  <= 4'd1 << din[1:0];
            end
        end
    end
end

endmodule
