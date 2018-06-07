`default_nettype none
module zxkbd      

(
input	wire		clk,         //clock 14 или более Мгц
input	wire		reset,       //вход сброса контроллера. Можно просто посадить на '0'.
output wire    res_k,       //выход RESET на компьютер. Аналогично делаются и другие спецкнопки
output wire		[12:1]	f,		
input wire		ps2_clk, 
input wire		ps2_data,
input wire		[7:0]	zx_kb_scan,  //вход сканирования клавиатуры (А15...А8)
output wire		[4:0]	zx_kb_out,   //выход сигналов КВ0...4 на порт FE компьютера
output wire		[4:0]	k_joy,		 //kempston on numpad keys
output wire		num_joy
);

assign          res_k       =   res_key;
assign			f			=	f_key;
assign			k_joy		=	kempston;
assign			num_joy		=	numlock;

reg		[7:0]	zx_kb;
reg             res_key  =   1'b1;
reg		[12:1]	f_key	 =	 12'b000000000000;
reg				ex_code	 =   0;	
reg		[3:0]	state    =   0;
reg				press_release;
reg				strobe;
reg		[4:0]	kempston;
reg				numlock;


always @(posedge clk) begin
	if (reset) begin
		state			<= 0;
		f_key			<= 12'b000000000000;
		res_key         <= 1;				
	end 
	else begin
		case (state)
		0: begin
			if (ps2dsr) begin
					ps2rden <= 1;
					state 	<= 1;
					end
			end
		1:	begin
				state <= 2;
				ps2rden <= 0;
			end
		2:	begin
				ps2rden <= 0;
				if (ps2q == 8'hF0) begin
					state <= 6;
				end
				else if (ps2q == 8'hE0) begin
						ex_code	<= 1;
						state <= 0;
					end
							else	begin
									state <= 4;
									end
			end		
		4:	begin
			if ((ps2q == 8'h12) && ex_code) begin
				ex_code <= 0;
				state <= 0;
			end
				else
					case(ps2q)
						8'h7e:          res_key     	<= 1'b0;        //reset
						8'h07:			f_key[12]		<= 1'b1;
						8'h78:			f_key[11]		<= 1'b1;
						8'h09:			f_key[10]		<= 1'b1;
						8'h01:			f_key[9]		<= 1'b1;
						8'h0a:			f_key[8]		<= 1'b1;
						8'h83:			f_key[7]		<= 1'b1;
						8'h0b:			f_key[6]		<= 1'b1;
						8'h03:			f_key[5]		<= 1'b1;
						8'h0c:			f_key[4]		<= 1'b1;
						8'h04:			f_key[3]		<= 1'b1;
						8'h06:			f_key[2]		<= 1'b1;
						8'h05:			f_key[1]		<= 1'b1;
						8'h77:			numlock			<= ~numlock;
						default: begin
									zx_kb <= ps2q;
									press_release	<= 1'b1;
									strobe	<=	1'b1;
						end
					endcase
			state <= 5;
			end
		5:	begin
			strobe	<=	1'b0;
			state	<=	0;
			ex_code <=  0;
			end
			
		6:	begin
				if (ps2dsr) begin
					ps2rden <= 1;
					state <= 7;
				end
			end
			
		7:	begin
				ps2rden <= 0;
				state <= 8;
			end
			
		8:	begin
			if (ps2q == 8'hE0) begin
				ex_code <= 1'b1;
				state <=  6;
				end
			else	begin	
					state <= 9;
					end
			end
		9:	begin
				if ((ps2q == 8'h12) && ex_code) begin
					ex_code <= 0;
					state <= 6;
				end
			else
				case(ps2q)
					8'h7e:          res_key     	<= 1'b1;        //reset
					8'h07:			f_key[12]		<= 1'b0;
					8'h78:			f_key[11]		<= 1'b0;
					8'h09:			f_key[10]		<= 1'b0;
					8'h01:			f_key[9]		<= 1'b0;
					8'h0a:			f_key[8]		<= 1'b0;
					8'h83:			f_key[7]		<= 1'b0;
					8'h0b:			f_key[6]		<= 1'b0;
					8'h03:			f_key[5]		<= 1'b0;
					8'h0c:			f_key[4]		<= 1'b0;
					8'h04:			f_key[3]		<= 1'b0;
					8'h06:			f_key[2]		<= 1'b0;
					8'h05:			f_key[1]		<= 1'b0;
					default: 
						begin
						zx_kb <= ps2q;
						press_release	<= 1'b0;
						strobe	<=	1'b1;
						end
				endcase
				state <= 10;
			end
		10:	begin
			ex_code <=  0;
			strobe	<=	1'b0;
			state	<=	0;
			end
		endcase
	end
end


assign	zx_kb_out = ~(5'b000 |  ((zx_kb_scan[0]==1'b0)? keymatrix[7]: 5'h0) |
								((zx_kb_scan[1]==1'b0)? keymatrix[6]: 5'h0) |
								((zx_kb_scan[2]==1'b0)? keymatrix[5]: 5'h0) |
								((zx_kb_scan[3]==1'b0)? keymatrix[4]: 5'h0) |
								((zx_kb_scan[4]==1'b0)? keymatrix[3]: 5'h0) |
								((zx_kb_scan[5]==1'b0)? keymatrix[2]: 5'h0) |
								((zx_kb_scan[6]==1'b0)? keymatrix[1]: 5'h0) |
								((zx_kb_scan[7]==1'b0)? keymatrix[0]: 5'h0) );

reg		[4:0]	keymatrix[0:7];

always	@(posedge	clk)
begin
	if (reset) begin
		keymatrix[0]	<= 5'h0;
		keymatrix[1]	<= 5'h0;
		keymatrix[2]	<= 5'h0;
		keymatrix[3]	<= 5'h0;
		keymatrix[4]	<= 5'h0;
		keymatrix[5]	<= 5'h0;
		keymatrix[6]	<= 5'h0;
		keymatrix[7]	<= 5'h0;
	end

	else	begin
				if (strobe) begin
					case ({ex_code, zx_kb[7:0]})
					9'h029:	keymatrix[0][0]	<= press_release; //Space
			 9'h114,9'h014:	keymatrix[0][1]	<= press_release; //Symbol Shift
					9'h03a:	keymatrix[0][2]	<= press_release; //M
			 9'h071,9'h049: begin
					        keymatrix[0][2]	<= press_release; //.
					        keymatrix[0][1]	<= press_release; //
					        end
					9'h031:	keymatrix[0][3]	<= press_release; //N
					9'h032:	keymatrix[0][4]	<= press_release; //B
					9'h07c: begin
					        keymatrix[0][4]	<= press_release; //*
					        keymatrix[0][1]	<= press_release; //
					        end

			 9'h15a,9'h05a:	keymatrix[1][0]	<= press_release; //Enter
					9'h04b:	keymatrix[1][1]	<= press_release; //L
					9'h042:	keymatrix[1][2]	<= press_release; //K
					9'h079: begin
					        keymatrix[1][2]	<= press_release; //+
					        keymatrix[0][1]	<= press_release; //
					        end
					9'h03b:	keymatrix[1][3]	<= press_release; //J
		     9'h07b,9'h04e: begin
					        keymatrix[1][3]	<= press_release; //-
					        keymatrix[0][1]	<= press_release; //
					        end
					9'h033:	keymatrix[1][4]	<= press_release; //H
                                   
					9'h04d:	keymatrix[2][0]	<= press_release; //P
					9'h044:	keymatrix[2][1]	<= press_release; //O
					9'h043:	keymatrix[2][2]	<= press_release; //I
					9'h03c:	keymatrix[2][3]	<= press_release; //U
					9'h035:	keymatrix[2][4]	<= press_release; //Y
                                   
		     9'h045,9'h070:	keymatrix[3][0]	<= press_release; //0
					9'h066: begin
					        keymatrix[3][0]	<= press_release; //Delete
					        keymatrix[7][0]	<= press_release; //
					        end
    		  9'h046,9'h07d:keymatrix[3][1]	<= press_release; //9
					 9'h03e:keymatrix[3][2]	<= press_release; //8
			  9'h03d,9'h06c:keymatrix[3][3]	<= press_release; //7
					 9'h036:keymatrix[3][4]	<= press_release; //6
                                   
    		  9'h016,9'h069:keymatrix[4][0]	<= press_release; //1
			        9'h00d: begin
			                keymatrix[4][0]	<= press_release; //Edit
					        keymatrix[7][0]	<= press_release; //
					        end
			  9'h01e,9'h072:keymatrix[4][1]	<= press_release; //2
			        9'h058: begin
					        keymatrix[4][1]	<= press_release; //Caps Lock
					        keymatrix[7][0]	<= press_release; //
					        end
			  9'h026,9'h07a:keymatrix[4][2]	<= press_release; //3
					 9'h025:keymatrix[4][3]	<= press_release; //4
					 9'h02e:keymatrix[4][4]	<= press_release; //5
                                   
			        9'h015:	keymatrix[5][0]	<= press_release; //Q
			        9'h01d:	keymatrix[5][1]	<= press_release; //W
					9'h024:	keymatrix[5][2]	<= press_release; //E
					9'h02d:	keymatrix[5][3]	<= press_release; //R
					9'h02c:	keymatrix[5][4]	<= press_release; //T
                                   
		            9'h01c:	keymatrix[6][0]	<= press_release; //A
			        9'h01b:	keymatrix[6][1]	<= press_release; //S
			        9'h023:	keymatrix[6][2]	<= press_release; //D
			        9'h02b:	keymatrix[6][3]	<= press_release; //F
			        9'h034:	keymatrix[6][4]	<= press_release; //G

		      9'h012,9'h059:keymatrix[7][0]	<= press_release; //Caps Shift
		            9'h076: begin
					        keymatrix[0][1]	<= press_release; //Ext Mode
					        keymatrix[7][0]	<= press_release; //
					        end
					9'h01a:	keymatrix[7][1]	<= press_release; //Z
					9'h022:	keymatrix[7][2]	<= press_release; //X
					9'h021:	keymatrix[7][3]	<= press_release; //C
					9'h02a:	keymatrix[7][4]	<= press_release; //V
			 9'h14a,9'h04a: begin
					        keymatrix[7][4]	<= press_release; ///
					        keymatrix[0][1]	<= press_release; //
					        end
					9'h041: begin
					        keymatrix[0][3]	<= press_release; //,
					        keymatrix[0][1]	<= press_release; //
					        end
					9'h04c: begin
					        keymatrix[2][1]	<= press_release; //;
					        keymatrix[0][1]	<= press_release; //
					        end
					9'h052: begin
					        keymatrix[2][0]	<= press_release; //"
					        keymatrix[0][1]	<= press_release; //
					        end
					9'h05d: begin
					        keymatrix[7][1]	<= press_release; //:
					        keymatrix[0][1]	<= press_release; //
					        end 
					9'h055: begin
					        keymatrix[1][1]	<= press_release; //=
					        keymatrix[0][1]	<= press_release; //
					        end
					9'h054: begin
					        keymatrix[3][2]	<= press_release; //(
					        keymatrix[0][1]	<= press_release; //
					        end
					9'h05b: begin
					        keymatrix[3][1]	<= press_release; //)
					        keymatrix[0][1]	<= press_release; //
					        end
					9'h16b: begin
							keymatrix[7][0]	<= press_release; //Caps Shift
							keymatrix[4][4]	<= press_release; //5
							end
					9'h175: begin
							keymatrix[7][0]	<= press_release; //Caps Shift
							keymatrix[3][3]	<= press_release; //7
							end
					9'h174: begin
							keymatrix[7][0]	<= press_release; //Caps Shift
							keymatrix[3][2]	<= press_release; //8
							end
					9'h172: begin
							keymatrix[7][0]	<= press_release; //Caps Shift
							keymatrix[3][4]	<= press_release; //6
							end
							
			9'h06b :if (~numlock) keymatrix[4][3]	<= press_release; //4
					else kempston[1] <= press_release; //right_joy
			9'h073 :if (~numlock) keymatrix[4][4]	<= press_release; //5
					else kempston[2] <= press_release; //down_joy
			9'h074 :if (~numlock) keymatrix[3][4]	<= press_release; //6
					else kempston[0] <= press_release; //left_joy
			9'h075 :if (~numlock) keymatrix[3][2]	<= press_release; //8							
					else kempston[3] <= press_release; //up_joy

					9'h111: kempston[4] <= press_release; //fire_joy		

					endcase
									
				end
		end
end

reg				ps2rden;
wire	[7:0]	ps2q;	
wire			ps2dsr;	
	
	
ps2_keyboard ps2_keyboard(
	.clk							(clk),
	.reset							(reset),
	.ps2_clk_i						(ps2_clk),
	.ps2_data_i						(ps2_data),
	.rx_released					(),
	.rx_shift_key_on				(),
	.rx_scan_code					(ps2q),
	.rx_ascii						(),
	.rx_data_ready					(ps2dsr),  
	.rx_read						(ps2rden)     
  );

endmodule
