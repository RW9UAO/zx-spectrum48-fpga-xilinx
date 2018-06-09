/*

`define macro_name macro_text
`ifdef macro_name
	group_of_lines
`else
	group_of_lines
`endif

*/
`timescale 1ns / 1ps

/////////////////////////////////////////////////////////////////////////////////
//	based on
//	Ewgeny7 tutorial
//	https://github.com/gdevic/A-Z80
//
/////////////////////////////////////////////////////////////////////////////////
module main_top(
	//----------------------------
	input  wire       CLK_50M,        // 100MHz system clock signal
	//----------------------------
	input  wire reset,					// CPU reset
	//input  wire [3:0] key,			// if want all 4 key
	//input	 wire key,					// if need only one button
	//output wire [7:0] LED,			// onboard LEDs
	output wire [15:0] usb_dbg,		// Cypress FX2LP chip for logic analyzer
	//----------------------------	// VGA signals
	output wire VGA_VSYNC,
	output wire VGA_HSYNC,
	output wire [4:0] VGA_R,
	output wire [5:0] VGA_G,
	output wire [4:0] VGA_B,
	//-------------------------
	output wire BUZZER,					// std ZX sound
	output wire tape_out,				// to tape recorder
	input wire tape_in,				// from tape recorder
	//-------------------------		// PS2
	input wire PS2_KBCLK,
	input wire PS2_KBDAT

    );
//==================================================================================
wire clk_150mhz;
wire clock;
wire clk_cpu;
reg [1:0]clk_cnt;
reg [4:0]flash;
reg [8:0]hcnt;
reg [9:0]vcnt;
reg hsync;
reg vsync;
reg screen;
reg screen1;
reg blank;
reg [7:0]vid_0_reg;
reg [7:0]vid_1_reg;
reg [7:0]vid_b_reg;
reg [7:0]vid_c_reg;
wire vid_dot;
reg vid_sel;
reg r,rb;
reg g,gb;
reg b,bb;

wire [15:0]cpu_a_bus;
wire [7:0]cpu_d_bus;
wire cpu_mreq_n;
wire cpu_iorq_n;
wire cpu_wr_n;
wire cpu_rd_n;
reg cpu_int_n;
reg int_signal;
wire M1;

wire rom_sel;

reg port_ff_sel;
reg port_fe_sel;
reg port_1f_sel;
reg port_7ffd_sel;
reg [4:0]port_fe;
wire [7:0]kb_a_bus;
wire [4:0]kb_do_bus;
wire [4:0]kempston;
reg [7:0]port_ff;
reg [7:0]port_7ffd = 8'b00010000;

wire [15:0] sram_a;
wire [7:0] sram_di;
wire [7:0] sram_do;
reg [7:0] sram_do_r;
wire SRAM_nWE;

wire VCC;
wire GND;

//reg rom_a14;
//wire [14:0] rom_addr;
//wire [7:0]rom_do;

//==================================================================================
pll14 PLL14(
	.CLK_IN1(CLK_50M),		// input main clock
	.CLK_OUT1(clock),			// 14 MHz pixel clock
	.CLK_OUT2(clk_150mhz)	// BRAM clock
);
//==================================================================================
z80_top_direct_n Z80(
	.CLK(clk_cpu),
	.nM1(M1),
	.nMREQ(cpu_mreq_n),
	.nIORQ(cpu_iorq_n),
	.nRD(cpu_rd_n),
	.nWR(cpu_wr_n),
	.nRFSH(),
	.nHALT(),
	.nBUSACK(),
	.nWAIT(VCC),
	.nINT(cpu_int_n),
	.nNMI(VCC),
	.nRESET(reset),
	.nBUSRQ(VCC),
	.A(cpu_a_bus),
	.D(cpu_d_bus)
);
//==================================================================================
// block RAM as plane 64 kb SRAM
// lower 16kb main BIOS preloaded from .coe
bios_only SRAM(
// first 2 kb of main BIOS overwritten by test program, videoRAM contain picture
//test_plus_pict SRAM(									
  .clka(clk_150mhz),
  .wea( ~SRAM_nWE),
  .addra(sram_a),
  .dina(sram_di),
  .douta(sram_do)
);
//==================================================================================
/*
// dedicated ram as 16kb ROM
// tooooo many time for place&route and a big part of chip logic
//bios_plus_test ROM(
//test_rom ROM(
rom_bios ROM(
//  .a(rom_addr),
  .a(cpu_a_bus[13:0]),
  .spo(rom_do)
);*/
//==================================================================================
zxkbd kbd(
		.clk(clock),
		//.reset(GND),
		.reset( ~reset),
		.res_k(),
		.ps2_clk(PS2_KBCLK),
		.ps2_data(PS2_KBDAT),
		.zx_kb_scan(kb_a_bus),
		.zx_kb_out(kb_do_bus),
		.k_joy(kempston),
		.f(),   
		.num_joy()
);
//==================================================================================
assign VCC = 1'b1;	// std logic
assign GND = 1'b0;	// std logic

// CPU 3,5 MHz clock
assign clk_cpu = clk_cnt[1];

// CPU want lower 16kb
assign rom_sel = ( cpu_a_bus[15:14] == 2'b00 ) ? 1'b1 : 1'b0;

// CPU want acsess to port
always @(*)begin
	if (cpu_a_bus[7:0] == 8'hFF && cpu_iorq_n == 0) begin
		port_ff_sel <= 1'b1;
	end else begin
		port_ff_sel <= 1'b0;
	end
end
always @(*)begin
	if (cpu_a_bus[7:0] == 8'hFE && cpu_iorq_n == 0) begin
		port_fe_sel <= 1'b1;
	end else begin
		port_fe_sel <= 1'b0;
	end
end
always @(*)begin
	if (cpu_a_bus[7:0] == 8'h1F && cpu_iorq_n == 0) begin
		port_1f_sel <= 1'b1;
	end else begin
		port_1f_sel <= 1'b0;
	end
end
always @(*)begin
	if (cpu_a_bus == 16'h7ffd && cpu_iorq_n == 0) begin
		port_7ffd_sel <= 1'b1;
	end else begin
		port_7ffd_sel <= 1'b0;
	end
end

// RAM write, protect for lower 16kb and from video controller
assign SRAM_nWE = ( vid_sel == 0 && cpu_mreq_n == 0 && cpu_wr_n == 0 && rom_sel == 0 )? 1'b0 : 1'b1;

// input RAM data alwas connect to CPU data bus
assign sram_di = cpu_d_bus;

// keyboard decoder use top of addr bus
assign kb_a_bus = cpu_a_bus[15:8];

// CPU data bus multiplexer
assign cpu_d_bus =
// read from memory, no divide for RAM and ROM
	( cpu_iorq_n == 1 && cpu_mreq_n == 0 && cpu_rd_n == 0 ) ? sram_do_r :
// read read from xFE port
	( cpu_mreq_n == 1 && cpu_rd_n == 0 && port_fe_sel == 1) ? 
	{ 1'b1, tape_in, 1'b1, kb_do_bus} :
// read from kempston joy
	( cpu_mreq_n == 1 && cpu_rd_n == 0 && port_1f_sel == 1) ? 
	{ 3'b111, kempston} :
// read read from xFF port
	( cpu_mreq_n == 1 && cpu_rd_n == 0 && port_ff_sel == 1) ? 
	port_ff :
// read read from x7FFD port
	( cpu_mreq_n == 1 && cpu_rd_n == 0 && port_7ffd_sel == 1) ? 
	port_7ffd :
// read from unised ports, always read xFF
	( cpu_iorq_n == 0 && cpu_mreq_n == 1 && cpu_rd_n == 0 ) ?
	8'b11111111 :
// CPU in write mode
	8'bZZZZZZZZ;

always @(negedge clock)begin
	if (port_7ffd_sel && cpu_wr_n ) begin
		port_7ffd <= cpu_d_bus;
	end
end

//========================================================
// port xFF not so good, arcanoid not work
always @(*)begin
	if (vid_sel && hcnt[2:0] == 3'b101 ) begin
		port_ff <= sram_do;
	end
end

// VGA signals
assign VGA_R = {r,rb,rb,rb,rb};
assign VGA_G = {g,gb,gb,gb,gb,gb};
assign VGA_B = {b,bb,bb,bb,bb};
assign VGA_HSYNC = ( hsync == 0 ) ? 1'b0 : 1'b1;
assign VGA_VSYNC = ( vsync == 0 ) ? 1'b0 : 1'b1; 

// std ZX beeper
assign BUZZER = port_fe[4];

// tape recorder
assign tape_out = port_fe[3];
//assign tape_in = ??;


//assign rom_addr = { rom_a14, cpu_a_bus[13:0]};

// LEDs for light!	
//assign LED = kb_do_bus;

// signals for FX2LP + sigrok
assign usb_dbg[7:0] = cpu_d_bus[7:0];
assign usb_dbg[8] = M1;
assign usb_dbg[9] = cpu_rd_n;
assign usb_dbg[10] = cpu_wr_n;
assign usb_dbg[11] = cpu_mreq_n;
assign usb_dbg[12] = cpu_iorq_n;
assign usb_dbg[13] = SRAM_nWE;
assign usb_dbg[14] = int_signal;
assign usb_dbg[15] = cpu_int_n;

//======================================================
// register for solid CPU data read from RAM
// prevent data damage from video controller
//always @(posedge clk_150mhz)begin
//always @(negedge clk_150mhz)begin
// glithes on 150mhz

always @(negedge clock)begin	// work fine
//always @(posedge clock)begin	// not work
	if(vid_sel == 0 && cpu_rd_n == 0 && cpu_mreq_n == 0)begin
		sram_do_r <= sram_do;
	end
end

//======================================================
// generate 3,5 MHz CPU clock from 14 Mhz pixel clock
always @(negedge clock) begin
	clk_cnt <= clk_cnt + 1'b1;
end

//======================================================
// INT inpulse generation
always @(posedge clock) begin
	// generate two INT impulse, as in tutorial
	//if ( vcnt[9:1] == 239 && hcnt == 316) begin
	// for one INT impulse, work fine
	if ( vcnt == 478 && hcnt == 316) begin 
		int_signal <= 1'b1;
	end else begin
		int_signal <= 1'b0;
	end
end

always @(posedge clk_150mhz) begin
	if( int_signal == 1'b1) begin
		cpu_int_n <= 1'b0;
	end
	// 388-316=72 pix;  32/448 * 72  = 5.14uS from tutor
	//if ( hcnt == 388 ) begin	
	// 428-316=112 pix; 32/448 * 112 = 8uS as original
	if ( hcnt == 428 ) begin
		cpu_int_n <= 1'b1;
	end
end

//======================================================
// horiz sync counter
always @(negedge clock) begin
	
	hcnt <= hcnt + 1'b1;
	
	if ( hcnt == 448 ) begin
		hcnt <= 0;
	end
end

//======================================================
// vertical sync counter
always @(negedge clock) begin

	if ( hcnt == 328 ) begin
	
		vcnt <= vcnt + 1'b1;
	
		if ( vcnt[9:1] == 312 ) begin
			vcnt[9:1] <= 0;
		end
		// flash	signal
		if ( vcnt == 10'b1000000000) begin
			flash <= flash + 1'b1;
		end
	end
end

//==================================================
// VGA sync
always @(posedge clock) begin
	if ( hcnt == 328 ) begin
		hsync <= 1'b0;
	end else 
	if ( hcnt == 381 ) begin
		hsync <= 1'b1;
	end
end

//==================================================
// VGA sync
always @(posedge clock) begin
	if ( vcnt[9:1] == 256 ) begin
		vsync <= 1'b0;
	end else
	if ( vcnt[9:1] == 260 ) begin
		vsync <= 1'b1;
	end
end

//==================================================
// signal for VGA picture
always @(posedge clock) begin
	if ( (hcnt > 301 && hcnt < 417) || (vcnt[9:1] > 224 && vcnt[9:1] < 285) ) begin
		blank <= 1'b1;
	end else begin
		blank <= 1'b0;
	end
end

//==================================================
// enable video output
always @(posedge clock) begin
	if ( hcnt < 256 && vcnt[9:1] < 192 ) begin
		screen <= 1'b1;
	end else begin
		screen <= 1'b0;
	end
end

//=================================================
// store pixels and attr from video ram to temp buffers
always @(posedge clock) begin
	case ( hcnt[2:0] )
		3'b100: vid_0_reg <= sram_do;
		3'b101: vid_1_reg <= sram_do;
		3'b111: begin
			vid_b_reg <= vid_0_reg;
			vid_c_reg <= vid_1_reg;
			screen1 <= screen;
//			port_ff <= vid_1_reg;
			end
	endcase
end

//=================================================
// video controller need acsces to video ram
always @(posedge clk_150mhz) begin
	if ( hcnt[2:1] == 2'b10 ) begin
		vid_sel <= 1'b1;
	end else begin
		vid_sel <= 1'b0;
	end
end

//==================================================
// use multipexor as pixel shift
assign vid_dot = 	( hcnt[2:0] == 3'b000) ? vid_b_reg[7] :
						( hcnt[2:0] == 3'b001) ? vid_b_reg[6] :
						( hcnt[2:0] == 3'b010) ? vid_b_reg[5] :
						( hcnt[2:0] == 3'b011) ? vid_b_reg[4] :
						( hcnt[2:0] == 3'b100) ? vid_b_reg[3] :
						( hcnt[2:0] == 3'b101) ? vid_b_reg[2] :
						( hcnt[2:0] == 3'b110) ? vid_b_reg[1] :
						vid_b_reg[0];

//==================================================
// RAM multiplexor
assign sram_a = ( vid_sel == 1) ?	// if video controller time
		(hcnt[0] == 1'b0) ? 				// check for pixels or attribute
		// pixel
		{3'b010, vcnt[8:7], vcnt[3:1], vcnt[6:4], hcnt[7:3]} :
		// attr
		{6'b010110, vcnt[8:4], hcnt[7:3]} : 
		// video controller off, all ram to cpu
		cpu_a_bus;

//==================================================
// CPU write to port xFE
always @( posedge clock ) begin
	if ( port_fe_sel == 1 && cpu_wr_n == 0) begin
		port_fe <= cpu_d_bus[4:0];
	end
end

//==================================================
// picture magic
wire [2:0]selector;
assign selector = {vid_dot, flash[4], vid_c_reg[7]};

always @(posedge clock) begin
	
	if( blank == 0 ) begin
		if (screen1 == 1) begin
			if ( selector == 3'b000 || selector == 3'b010 ||
				  selector == 3'b011 || selector == 3'b101 ) begin
						b <= vid_c_reg[3:3];
						bb <= ( vid_c_reg[3:3] && vid_c_reg[6:6] );
						r <= vid_c_reg[4:4];
						rb <= ( vid_c_reg[4:4] && vid_c_reg[6:6] );
						g <= vid_c_reg[5:5];
						gb <= ( vid_c_reg[5:5] && vid_c_reg[6:6] );
			end else begin
						b <= vid_c_reg[0:0];
						bb <= ( vid_c_reg[0:0] && vid_c_reg[6:6] );
						r <= vid_c_reg[1:1];
						rb <= ( vid_c_reg[1:1] && vid_c_reg[6:6] );
						g <= vid_c_reg[2:2];
						gb <= ( vid_c_reg[2:2] && vid_c_reg[6:6] );
			end
		end else begin // screen1 == 0
						b <= port_fe[0];
						r <= port_fe[1];
						g <= port_fe[2];
						rb <= 0;
						gb <= 0;
						bb <= 0;
		end
	end else begin	//blank == 1
						b <= 0;
						r <= 0;
						g <= 0;
						rb <= 0;
						gb <= 0;
						bb <= 0;
	end
end










endmodule
