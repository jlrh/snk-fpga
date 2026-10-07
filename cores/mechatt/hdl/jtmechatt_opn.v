/*  This file is part of JT12.

    JT12 is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT12 is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT12.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 14-2-2016
*/

`timescale 1ns/1ps
module jtmechatt_opn(
    input                rst,
    input                clk,
    input                cen,
    input         [ 7:0] din,
    input         [ 1:0] addr,
    input                cs_n,
    input                wr_n,
    output        [ 7:0] psg_dout,
    output               sample,

    output               ev_A,
    output               ev_B,
    output               en_A,
    output               en_B,
    output               rst_A,
    output               rst_B,

    output signed [15:0] fm_left,
    output signed [15:0] fm_right,
    output        [ 9:0] psg_snd
);

parameter num_ch=6, JT49_DIV=3;

wire write = !cs_n && !wr_n;
wire clk_en, clk_en_ssg;

wire    [9:0]   value_A;
wire    [7:0]   value_B;
wire            load_A, load_B;
wire            overflow_A;
wire            fast_timers;
wire            zero;
wire    [2:0]   lfo_freq;
wire            lfo_en;
wire            amsen_IV;
wire    [ 2:0]  dt1_I;
wire    [ 3:0]  mul_II;
wire    [ 6:0]  tl_IV;
wire    [ 4:0]  keycode_II;
wire    [ 4:0]  ar_I, d1r_I, d2r_I;
wire    [ 3:0]  rr_I, sl_I;
wire    [ 1:0]  ks_II;
wire            ssg_en_I;
wire    [2:0]   ssg_eg_I;
wire            keyon_I;
wire    [9:0]   eg_IX;
wire            pg_rst_II;
wire    [10:0]  fnum_I;
wire    [ 2:0]  block_I;
wire    [ 1:0]  rl;
wire    [ 2:0]  fb_II, alg_I, pms_I;
wire    [ 1:0]  ams_IV;
wire            pcm_en, pcm_wr;
wire    [ 8:0]  pcm;
wire            pg_stop, eg_stop;
wire            ch6op;
wire    [ 2:0]  cur_ch;
wire    [ 1:0]  cur_op;
wire            xuse_internal, yuse_internal;
wire            xuse_prevprev1, xuse_prev2, yuse_prev1, yuse_prev2;
wire    [ 9:0]  phase_VIII;
wire            s1_enters, s2_enters, s3_enters, s4_enters;
wire    [6:0]   lfo_mod;
wire    [3:0]   psg_addr;
wire    [7:0]   psg_data;
wire            psg_wr_n;
wire            busy;
wire [16:0] addr_a;
wire [ 2:0] up_addr, up_lracl;
wire        up_start, up_end, up_aon;
wire [ 7:0] aon_a, lracl;
wire [ 5:0] atl_a;
wire        acmd_on_b, acmd_rep_b, acmd_rst_b, acmd_up_b;
wire [ 1:0] alr_b;
wire [15:0] astart_b, aend_b, adeltan_b;
wire [ 7:0] aeg_b;
wire [ 6:0] flag_ctl, flag_mask;
wire [ 1:0] div_setting;
wire        clk_en_2, clk_en_666, clk_en_111, clk_en_55;
wire        flag_A;
wire [ 8:0] op_result;
wire [13:0] op_result_hd;
reg         cen_reg;

always @(posedge clk) cen_reg <= cen;

assign sample = zero;

jt12_mmr #(.use_ssg(1),.num_ch(num_ch),.use_pcm(0), .use_adpcm(0), .mask_div(1))
    u_mmr(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_reg   ),
    .clk_en     ( clk_en    ),
    .clk_en_2   ( clk_en_2  ),
    .clk_en_ssg ( clk_en_ssg),
    .clk_en_666 ( clk_en_666),
    .clk_en_111 ( clk_en_111),
    .clk_en_55  ( clk_en_55 ),
    .din        ( din       ),
    .write      ( write     ),
    .addr       ( addr      ),
    .busy       ( busy      ),
    .ch6op      ( ch6op     ),
    .cur_ch     ( cur_ch    ),
    .cur_op     ( cur_op    ),
    .lfo_freq   ( lfo_freq  ),
    .lfo_en     ( lfo_en    ),
    .value_A    ( value_A   ),
    .value_B    ( value_B   ),
    .load_A     ( load_A    ),
    .load_B     ( load_B    ),
    .enable_irq_A( en_A     ),
    .enable_irq_B( en_B     ),
    .clr_flag_A ( rst_A     ),
    .clr_flag_B ( rst_B     ),
    .flag_A     ( flag_A    ),
    .overflow_A ( overflow_A),
    .fast_timers( fast_timers),
    .pcm        ( pcm       ),
    .pcm_en     ( pcm_en    ),
    .pcm_wr     ( pcm_wr    ),
    .aon_a      ( aon_a     ),
    .atl_a      ( atl_a     ),
    .addr_a     ( addr_a    ),
    .lracl      ( lracl     ),
    .up_start   ( up_start  ),
    .up_end     ( up_end    ),
    .up_addr    ( up_addr   ),
    .up_lracl   ( up_lracl  ),
    .up_aon     ( up_aon    ),
    .acmd_on_b  ( acmd_on_b ),
    .acmd_rep_b ( acmd_rep_b),
    .acmd_rst_b ( acmd_rst_b),
    .acmd_up_b  ( acmd_up_b ),
    .alr_b      ( alr_b     ),
    .astart_b   ( astart_b  ),
    .aend_b     ( aend_b    ),
    .adeltan_b  ( adeltan_b ),
    .aeg_b      ( aeg_b     ),
    .flag_ctl   ( flag_ctl  ),
    .flag_mask  ( flag_mask ),
    .xuse_prevprev1 ( xuse_prevprev1 ),
    .xuse_internal  ( xuse_internal  ),
    .yuse_internal  ( yuse_internal  ),
    .xuse_prev2     ( xuse_prev2     ),
    .yuse_prev1     ( yuse_prev1     ),
    .yuse_prev2     ( yuse_prev2     ),
    .fnum_I     ( fnum_I    ),
    .block_I    ( block_I   ),
    .pg_stop    ( pg_stop   ),
    .rl         ( rl        ),
    .fb_II      ( fb_II     ),
    .alg_I      ( alg_I     ),
    .pms_I      ( pms_I     ),
    .ams_IV     ( ams_IV    ),
    .amsen_IV   ( amsen_IV  ),
    .dt1_I      ( dt1_I     ),
    .mul_II     ( mul_II    ),
    .tl_IV      ( tl_IV     ),
    .ar_I       ( ar_I      ),
    .d1r_I      ( d1r_I     ),
    .d2r_I      ( d2r_I     ),
    .rr_I       ( rr_I      ),
    .sl_I       ( sl_I      ),
    .ks_II      ( ks_II     ),
    .eg_stop    ( eg_stop   ),
    .ssg_en_I   ( ssg_en_I  ),
    .ssg_eg_I   ( ssg_eg_I  ),
    .keyon_I    ( keyon_I   ),
    .zero       ( zero      ),
    .s1_enters  ( s1_enters ),
    .s2_enters  ( s2_enters ),
    .s3_enters  ( s3_enters ),
    .s4_enters  ( s4_enters ),
    .psg_addr   ( psg_addr  ),
    .psg_data   ( psg_data  ),
    .psg_wr_n   ( psg_wr_n  ),
    .debug_bus  ( 8'd0      ),
    .div_setting( div_setting)
);

wire timer_cen = fast_timers ? cen_reg : clk_en;
wire ovf_A, ovf_B, flagA_nc, flagB_nc;
assign overflow_A = ovf_A;
assign flag_A     = flagA_nc;
assign ev_A = timer_cen && zero && load_A && ovf_A;
assign ev_B = timer_cen && zero && load_B && ovf_B;

jt12_timer #(.CW(10)) u_timer_A(
    .clk        ( clk         ),
    .rst        ( rst         ),
    .cen        ( timer_cen   ),
    .zero       ( zero        ),
    .start_value( value_A     ),
    .load       ( load_A      ),
    .clr_flag   ( rst_A       ),
    .flag       ( flagA_nc    ),
    .overflow   ( ovf_A       )
);

jt12_timer #(.CW(8),.FREE_EN(1)) u_timer_B(
    .clk        ( clk         ),
    .rst        ( rst         ),
    .cen        ( timer_cen   ),
    .zero       ( zero        ),
    .start_value( value_B     ),
    .load       ( load_B      ),
    .clr_flag   ( rst_B       ),
    .flag       ( flagB_nc    ),
    .overflow   ( ovf_B       )
);

jt12_lfo u_lfo(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk_en     ( clk_en    ),
    .zero       ( zero      ),
    .lfo_rst    ( 1'b0      ),
    .lfo_en     ( lfo_en    ),
    .lfo_freq   ( lfo_freq  ),
    .lfo_mod    ( lfo_mod   )
);

jt49 #(.COMP(3'b01), .CLKDIV(JT49_DIV), .YM2203_LUMPED(0))
    u_psg(
    .rst_n      ( ~rst      ),
    .clk        ( clk       ),
    .clk_en     ( clk_en_ssg),
    .addr       ( psg_addr  ),
    .cs_n       ( 1'b0      ),
    .wr_n       ( psg_wr_n  ),
    .din        ( psg_data  ),
    .sound      ( psg_snd   ),
    .A          (           ),
    .B          (           ),
    .C          (           ),
    .dout       ( psg_dout  ),
    .sel        ( 1'b1      ),
    .IOA_out    (           ),
    .IOB_out    (           ),
    .IOA_in     ( 8'd0      ),
    .IOB_in     ( 8'd0      ),
    .IOA_oe     (           ),
    .IOB_oe     (           ),
    .sample     (           )
);

jt12_pg #(.num_ch(num_ch)) u_pg(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk_en     ( clk_en        ),
    .fnum_I     ( fnum_I        ),
    .block_I    ( block_I       ),
    .mul_II     ( mul_II        ),
    .dt1_I      ( dt1_I         ),
    .lfo_mod    ( lfo_mod       ),
    .pms_I      ( pms_I         ),
    .pg_rst_II  ( pg_rst_II     ),
    .pg_stop    ( pg_stop       ),
    .keycode_II ( keycode_II    ),
    .phase_VIII ( phase_VIII    )
);

wire [9:0] eg_V;

jt12_eg #(.num_ch(num_ch)) u_eg(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .clk_en         ( clk_en        ),
    .zero           ( zero          ),
    .eg_stop        ( eg_stop       ),
    .keycode_II     ( keycode_II    ),
    .arate_I        ( ar_I          ),
    .rate1_I        ( d1r_I         ),
    .rate2_I        ( d2r_I         ),
    .rrate_I        ( rr_I          ),
    .sl_I           ( sl_I          ),
    .ks_II          ( ks_II         ),
    .ssg_en_I       ( ssg_en_I      ),
    .ssg_eg_I       ( ssg_eg_I      ),
    .keyon_I        ( keyon_I       ),
    .lfo_mod        ( lfo_mod       ),
    .tl_IV          ( tl_IV         ),
    .ams_IV         ( ams_IV        ),
    .amsen_IV       ( amsen_IV      ),
    .eg_V           ( eg_V          ),
    .pg_rst_II      ( pg_rst_II     )
);

jt12_sh #(.width(10),.stages(4)) u_egpad(
    .clk    ( clk       ),
    .clk_en ( clk_en    ),
    .din    ( eg_V      ),
    .drop   ( eg_IX     )
);

jt12_op #(.num_ch(num_ch)) u_op(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .clk_en         ( clk_en        ),
    .pg_phase_VIII  ( phase_VIII    ),
    .eg_atten_IX    ( eg_IX         ),
    .fb_II          ( fb_II         ),
    .test_214       ( 1'b0          ),
    .s1_enters      ( s1_enters     ),
    .s2_enters      ( s2_enters     ),
    .s3_enters      ( s3_enters     ),
    .s4_enters      ( s4_enters     ),
    .xuse_prevprev1 ( xuse_prevprev1),
    .xuse_internal  ( xuse_internal ),
    .yuse_internal  ( yuse_internal ),
    .xuse_prev2     ( xuse_prev2    ),
    .yuse_prev1     ( yuse_prev1    ),
    .yuse_prev2     ( yuse_prev2    ),
    .zero           ( zero          ),
    .op_result      ( op_result     ),
    .full_result    ( op_result_hd  )
);

reg sum_en;
always @(*) begin
    case ( alg_I )
        default:   sum_en = s3_enters;
        3'd4:      sum_en = s1_enters | s3_enters;
        3'd5,3'd6: sum_en = ~s2_enters;
        3'd7:      sum_en = 1'b1;
    endcase
end

wire signed [15:0] opsx  = { {2{op_result_hd[13]}}, op_result_hd };
wire signed [15:0] opext = opsx >>> 1;

jt12_single_acc #(.win(16),.wout(16)) u_left(
    .clk        ( clk            ),
    .clk_en     ( clk_en         ),
    .op_result  ( opext          ),
    .sum_en     ( sum_en & rl[1] ),
    .zero       ( zero           ),
    .snd        ( fm_left        )
);

jt12_single_acc #(.win(16),.wout(16)) u_right(
    .clk        ( clk            ),
    .clk_en     ( clk_en         ),
    .op_result  ( opext          ),
    .sum_en     ( sum_en & rl[0] ),
    .zero       ( zero           ),
    .snd        ( fm_right       )
);

endmodule
