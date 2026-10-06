module gwar_blankmap(
    input             clk,
    input      [25:0] ioctl_addr,
    input      [ 7:0] prog_data,
    input             prog_we,
    input      [10:0] op16_addr,
    output            op16,
    input      [ 9:0] op32_addr,
    output            op32
);

localparam [25:0] S16 = `JTFRAME_BA3_START, S32 = `SP32_START, S32E = `JTFRAME_PROM_START;

wire        in16 = ioctl_addr >= S16 && ioctl_addr < S32;
wire        in32 = ioctl_addr >= S32 && ioctl_addr < S32E;
wire [25:0] o16  = ioctl_addr - S16;
wire [25:0] o32  = ioctl_addr - S32;
wire        opq  = prog_we && prog_data != 8'hFF;

jtframe_dual_ram #(.DW(1), .AW(11)) u_op16(
    .clk0( clk ), .data0( 1'b1 ), .addr0( o16[17:7] ), .we0( opq && in16 ), .q0(),
    .clk1( clk ), .data1( 1'b0 ), .addr1( op16_addr ), .we1( 1'b0 ), .q1( op16 ) );

jtframe_dual_ram #(.DW(1), .AW(10)) u_op32(
    .clk0( clk ), .data0( 1'b1 ), .addr0( o32[18:9] ), .we0( opq && in32 ), .q0(),
    .clk1( clk ), .data1( 1'b0 ), .addr1( op32_addr ), .we1( 1'b0 ), .q1( op32 ) );

endmodule
