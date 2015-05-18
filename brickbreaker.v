/*
 * Created by Rathusshan Kuganesan & Zhaoda Qu, Dec 2014
 * A Brickbreaker game for CSC258 - Computer Organization final project.
 * 
 * Control the paddle with the left and right keys to destroy all the bricks.
 * Keyboard controls coded in module keyboard(line 1109), brick/paddle/ball/background graphics
 * coded in module bars(line 872), collision and overall game logic coded in module brickbreaker.
*/

module brickbreaker(
//    Clock Input
  input CLOCK_50,    //    50 MHz
  input CLOCK_27,     //      27 MHz
//    Push Button
  input [3:0] KEY,      //    Pushbutton[3:0]
//    DPDT Switch
  input [17:0] SW,        //    Toggle Switch[17:0]
//    7-SEG Display
  output [6:0]    HEX0,HEX1,HEX2,HEX3,HEX4,HEX5,HEX6,HEX7,  // Seven Segment Digits
//    LED
  output [8:0]    LEDG,  //    LED Green[8:0]
  output [17:0] LEDR,  //    LED Red[17:0]
  //  PS2 data and clock lines
  input	PS2_DAT,
  input PS2_CLK,
//    GPIO
 inout [35:0] GPIO_0,GPIO_1,    //    GPIO Connections
//    TV Decoder
//TD_DATA,        //    TV Decoder Data bus 8 bits
//TD_HS,        //    TV Decoder H_SYNC
//TD_VS,        //    TV Decoder V_SYNC
  output TD_RESET,    //    TV Decoder Reset
// VGA
  output VGA_CLK,                           //    VGA Clock
  output VGA_HS,                            //    VGA H_SYNC
  output VGA_VS,                            //    VGA V_SYNC
  output VGA_BLANK,                        //    VGA BLANK
  output VGA_SYNC,                        //    VGA SYNC
  output [9:0] VGA_R,                           //    VGA Red[9:0]
  output [9:0] VGA_G,                             //    VGA Green[9:0]
  output [9:0] VGA_B                           //    VGA Blue[9:0]
);

//Keyboard-------------------------
wire reset = 1'b0;
wire [7:0] scan_code;

//reg [7:0] keyboard_code;
//reg [2:0] pin; 
reg [31:0] pin;
wire read, scan_ready;


oneshot pulser(
   .pulse_out(read),
   .trigger_in(scan_ready),
   .clk(CLOCK_50)
);

keyboard kbd(
  .keyboard_clk(PS2_CLK),
  .keyboard_data(PS2_DAT),
  .clock50(CLOCK_50),
  .reset(reset),
  .read(read),
  .scan_ready(scan_ready),
  .scan_code(scan_code)
);

always @(posedge scan_ready)
begin
   if (scan_code == 8'h74) begin
	pin = 1; 
   end
  else if (scan_code == 8'h6B) begin 
	pin = -1;
  end
  else begin
	pin = 0;
  end 
end

// ---------------------------------------

//    All inout port turn to tri-state
assign    GPIO_0        =    36'hzzzzzzzzz;
assign    GPIO_1        =    36'hzzzzzzzzz;

// reset delay gives some time for peripherals to initialize
wire DLY_RST;
Reset_Delay r0(    .iCLK(CLOCK_50),.oRESET(DLY_RST) );
wire RST_N = DLY_RST&KEY[0];

// Send switches to red leds 
assign LEDR = SW;

// Turn off green leds
assign LEDG = 8'h00;

wire [6:0] blank = 7'b111_1111;

// blank unused 7-segment digits
assign HEX0 = blank;
assign HEX1 = blank;
assign HEX2 = blank;
assign HEX3 = blank;
assign HEX4 = blank;
assign HEX5 = blank;
assign HEX6 = blank;
assign HEX7 = blank;

//Display
wire        VGA_CTRL_CLK;
wire        AUD_CTRL_CLK;
wire [29:0]    mVGA_RGB;
wire [9:0]    mCoord_X;
wire [9:0]    mCoord_Y; 

reg [31:0] px = 270;
reg [31:0] bx = 310;
reg [31:0] by = 250;

wire [31:0] px2;
wire [31:0] bx2;
wire [31:0] by2;

assign px2 = px;
assign bx2 = bx;
assign by2 = by;

assign    TD_RESET = 1'b1; // Enable 27 MHz

VGA_Audio_PLL     p1 (    
    .areset(~DLY_RST),
    .inclk0(CLOCK_27),
    .c0(VGA_CTRL_CLK),
    .c1(AUD_CTRL_CLK),
    .c2(VGA_CLK)
);

wire [29:0] rgb1, rgb2;

//Paddle movement from keyboard pulses
always @ (posedge pin) begin
	// H_pixels after 10px border - paddle size = 530
    if (pin == 1 && px < 530) begin
	    px = px + 20; 
    end
    else if (pin == -1 && px>10) begin 
	    px = px - 20;
    end 
end

//Game logic ball movement
wire clk;
slowclock(CLOCK_50, 0, clk);
reg [31:0] bdx = -1; //Ball starts moving in horizontal left direction
reg [31:0] bdy = 1; //Game should start with ball dropping

reg [26:0] bricks; //27 brick array
wire [26:0] bricks2; //copy of brick array to pass into bars
assign bricks2 = bricks;

//Bounce (change in direction) indicator
reg bounceX, bounceY;
//10 is the game screen border
//Ball control and horizontal movement
always @ (posedge clk) begin
    //Hit left screen then move right
    if (bx == 10 && ~bounceX) begin
		bdx = 1;
		bounceX <= 1;
    end
    //630 game screen (after last horizontal brick)
    //hit right screen then move left
    else if (bx >= 630 && ~bounceX) begin
		bdx = -1;
		bounceX <= 1;
    end
    else begin
		bounceX <= 0;
    end
end

//Game over condition,vertical movement = paddle collision & brick collision
always @ (posedge clk) begin
    // Move ball horizontally and vertically 1 pixel at a time.
    bx = bx + bdx;
    by = by + bdy;
    // Brick collisions, bricks[] checks if brick has been hit already or not
    if (bricks[0] == 0 && (bx > 10 && bx < 70) && (by > 10 && by < 40) && ~bounceY) begin
			bricks[0] <= 1;
			bdy = 1;  //Increment by 1, moves down
			bounceY <= 1;
    end
	 
    else if (bricks[1] == 0 &&(bx > 10 && bx < 70) && (by > 50 && by < 80) && ~bounceY) begin
			bricks[1] <= 1;
			bdy = 1;  //Increment by 1, moves down
			bounceY <= 1;
    end
	 
    else if (bricks[2] == 0 &&(bx > 10 && bx < 70) && (by > 90 && by < 120) && ~bounceY) begin
			bricks[2] <= 1;
			bdy = 1;  //Increment by 1, moves down
			bounceY <= 1;
    end
	 
    else if (bricks[3] == 0 &&(bx > 80 && bx < 140) && (by > 10 && by < 40) && ~bounceY) begin 
			bricks[3] <= 1;
			bdy = 1;  //Increment by 1, moves down
			bounceY <= 1;
    end
    else if (bricks[4] == 0 &&(bx > 80 && bx < 140) && (by > 50 && by < 80) && ~bounceY)  begin
			bricks[4] <= 1;
			bdy = 1;  //Increment by 1, moves down
			bounceY <= 1;
    end
	 
    else if (bricks[5] == 0 && (bx > 80 && bx < 140) && (by > 90 && by < 120) && ~bounceY) begin
			bricks[5] <= 1;
			bdy = 1;  //Increment by 1, moves down
			bounceY <= 1;
    end
	 
    else if (bricks[6] == 0 && (bx > 150 && bx < 210) && (by > 10 && by < 40) && ~bounceY) begin
			bricks[6] <= 1;
			bdy = 1;  //Increment by 1, moves down
			bounceY <= 1;
    end
    else if (bricks[7] == 0 && (bx > 150 && bx < 210) && (by > 50 && by < 80) && ~bounceY) begin
			bricks[7] <= 1;
			bdy = 1;  //Increment by 1, moves down
			bounceY <= 1;
    end
	 
    else if (bricks[8] ==0 && (bx > 150 && bx < 210) && (by > 90 && by < 120) && ~bounceY) begin
			bricks[8] <= 1;
			bdy = 1;  //Increment by 1, moves down
			bounceY <= 1;
    end
	 
	 else if (bricks[9] == 0 &&(bx > 220 && bx < 280) && (by > 10 && by < 40) && ~bounceY) begin
			bricks[9] <= 1;
			bdy = 1;  //Increment by 1, moves down
			bounceY <= 1;
    end
    else if (bricks[10] == 0 && (bx > 220 && bx < 280) && (by > 50 && by < 80) && ~bounceY) begin
			bricks[10] <= 1;
			bdy = 1;  //Increment by 1, moves down
			bounceY <= 1;
    end
	 
    else if (bricks[11] == 0 &&(bx > 220 && bx < 280) && (by > 90 && by < 120) && ~bounceY) begin
			bricks[11] <= 1;
			bdy = 1;  //Increment by 1, moves down
			bounceY <= 1;
    end
	 
    else if (bricks[12] == 0 && (bx > 290 && bx < 350) && (by > 10 && by < 40) && ~bounceY) begin
			bricks[12] <= 1;
			bdy = 1;  //Increment by 1, moves down
			bounceY <= 1;
    end
    else if (bricks[13] == 0 && (bx > 290 && bx < 350) && (by > 50 && by < 80) && ~bounceY) begin
			bricks[13] <= 1;
			bdy = 1;  //Increment by 1, moves down
			bounceY <= 1;
    end
	 
    else if (bricks[14] == 0 && (bx > 290 && bx < 350) && (by > 90 && by < 120) && ~bounceY) begin
			bricks[14] <= 1;
			bdy = 1;  //Increment by 1, moves down
			bounceY <= 1;
    end
	 
    else if (bricks[15] == 0 && (bx > 360 && bx < 420) && (by > 10 && by < 40) && ~bounceY) begin
			bricks[15] <= 1;
			bdy = 1;  //Increment by 1, moves down
			bounceY <= 1;
    end
    else if (bricks[16] == 0 && (bx > 360 && bx < 420) && (by > 50 && by < 80) && ~bounceY) begin
			bricks[16] <= 1;
			bdy = 1;  //Increment by 1, moves down
			bounceY <= 1;
    end
	 
    else if (bricks[17] == 0 &&(bx > 360 && bx < 420) && (by > 90 && by < 120) && ~bounceY) begin
			bricks[17] <= 1;
			bdy = 1;  //Increment by 1, moves down
			bounceY <= 1;
    end
	 
    else if (bricks[18] == 0 && (bx > 430 && bx < 490) && (by > 10 && by < 40) && ~bounceY) begin
			bricks[18] <= 1;
			bdy = 1;  //Increment by 1, moves down
			bounceY <= 1;
    end
    else if (bricks[19] == 0 && (bx > 430 && bx < 490) && (by > 50 && by < 80) && ~bounceY) begin
			bricks[19] <= 1;
			bdy = 1;  //Increment by 1, moves down
			bounceY <= 1;
    end
	 
    else if (bricks[20] == 0 && (bx > 430 && bx < 490) && (by > 90 && by < 120) && ~bounceY) begin
			bricks[20] <= 1;
			bdy = 1;  //Increment by 1, moves down
			bounceY <= 1;
    end
	 
    else if (bricks[21] == 0 && (bx > 500 && bx < 560) && (by > 10 && by < 40) && ~bounceY) begin
			bricks[21] <= 1;
			bdy = 1;  //Increment by 1, moves down
			bounceY <= 1;
    end
    else if (bricks[22] == 0 && (bx > 500 && bx < 560) && (by > 50 && by < 80) && ~bounceY) begin
			bricks[22] <= 1;
			bdy = 1;  //Increment by 1, moves down
			bounceY <= 1;
    end
	 
    else if (bricks[23] == 0 && (bx > 500 && bx < 560) && (by > 90 && by < 120) && ~bounceY) begin
			bricks[23] <= 1;
			bdy = 1;  //Increment by 1, moves down
			bounceY <= 1;
    end
	 
    else if (bricks[24] == 0 &&(bx > 570 && bx < 630) && (by > 10 && by < 40) && ~bounceY) begin
			bricks[24] <= 1;
			bdy = 1;  //Increment by 1, moves down
			bounceY <= 1;
    end
    else if (bricks[25] == 0 && (bx > 570 && bx < 630) && (by > 50 && by < 80) && ~bounceY) begin
			bricks[25] <= 1;
			bdy = 1;  //Increment by 1, moves down
			bounceY <= 1;
    end
	 
    else if (bricks[26] == 0 &&(bx > 570 && bx < 630) && (by > 90 && by < 120) && ~bounceY) begin
			bricks[26] <= 1;
			bdy = 1;  //Increment by 1, moves down
			bounceY <= 1;
    end
	 
    //--------------------------------------------------------------
    //Ball hits top at 10 then move down
    else if (by <= 10 && ~bounceY) begin
	    bdy = 1;  //Increment by 1, moves down
	    bounceY <= 1;
    end
    //ball hits paddle then move up
    //top of paddle is 460
    else if (by > 460 && ~bounceY && bx > px && bx < px + 120) begin
	    bdy = -1;  //Increment -1 moves up
	    bounceY <= 1;
    end
    //ball hits below paddle (470), game over
    else if (by == 470) begin
	//Start ball over at initial
	    bricks[26:0] <= 0;  //Reset bricks back to black colour and make them hit able again
	    bx = 310;
	    by = 250;
    end
    else begin
	    bounceY <= 0;
    end
end

bars c1(mCoord_X, mCoord_Y, px2, bx2, by2, bricks2, rgb1);
grayscale c2(mCoord_X, mCoord_Y, rgb2);

    
wire s = SW[0];
assign mVGA_RGB = (s? rgb2: rgb1);


vga_sync u1(
   .iCLK(VGA_CTRL_CLK),
   .iRST_N(RST_N),    
   .iRGB(mVGA_RGB),
   // pixel coordinates
   .px(mCoord_X),
   .py(mCoord_Y),
   // VGA Side
   .VGA_R(VGA_R),
   .VGA_G(VGA_G),
   .VGA_B(VGA_B),
   .VGA_H_SYNC(VGA_HS),
   .VGA_V_SYNC(VGA_VS),
   .VGA_SYNC(VGA_SYNC),
   .VGA_BLANK(VGA_BLANK)
);


endmodule

module    Reset_Delay(iCLK,oRESET);
input        iCLK;
output reg    oRESET;
reg    [19:0]    Cont;

always@(posedge iCLK)
begin
    if(Cont!=20'hFFFFF)
    begin
        Cont    <=    Cont+1'b1;
        oRESET    <=    1'b0;
    end
    else
    oRESET    <=    1'b1;
end

endmodule

// megafunction wizard: %ALTPLL%
// GENERATION: STANDARD
// VERSION: WM1.0
// MODULE: altpll 

// ============================================================
// File Name: VGA_Audio_PLL.v
// Megafunction Name(s):
//             altpll
//
// Simulation Library Files(s):
//             altera_mf
// ============================================================
// ************************************************************
// THIS IS A WIZARD-GENERATED FILE. DO NOT EDIT THIS FILE!
//
// 7.2 Build 175 11/20/2007 SP 1 SJ Web Edition
// ************************************************************
//Copyright (C) 1991-2007 Altera Corporation
//Your use of Altera Corporation's design tools, logic functions 
//and other software and tools, and its AMPP partner logic 
//functions, and any output files from any of the foregoing 
//(including device programming or simulation files), and any 
//associated documentation or information are expressly subject 
//to the terms and conditions of the Altera Program License 
//Subscription Agreement, Altera MegaCore Function License 
//Agreement, or other applicable license agreement, including, 
//without limitation, that your use is for the sole purpose of 
//programming logic devices manufactured by Altera and sold by 
//Altera or its authorized distributors.  Please refer to the 
//applicable agreement for further details.


// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
module VGA_Audio_PLL (
    areset,
    inclk0,
    c0,
    c1,
    c2);

    input      areset;
    input      inclk0;
    output      c0;
    output      c1;
    output      c2;

    wire [5:0] sub_wire0;
    wire [0:0] sub_wire6 = 1'h0;
    wire [2:2] sub_wire3 = sub_wire0[2:2];
    wire [1:1] sub_wire2 = sub_wire0[1:1];
    wire [0:0] sub_wire1 = sub_wire0[0:0];
    wire  c0 = sub_wire1;
    wire  c1 = sub_wire2;
    wire  c2 = sub_wire3;
    wire  sub_wire4 = inclk0;
    wire [1:0] sub_wire5 = {sub_wire6, sub_wire4};

    altpll    altpll_component (
                .inclk (sub_wire5),
                .areset (areset),
                .clk (sub_wire0),
                .activeclock (),
                .clkbad (),
                .clkena ({6{1'b1}}),
                .clkloss (),
                .clkswitch (1'b0),
                .configupdate (1'b0),
                .enable0 (),
                .enable1 (),
                .extclk (),
                .extclkena ({4{1'b1}}),
                .fbin (1'b1),
                .fbmimicbidir (),
                .fbout (),
                .locked (),
                .pfdena (1'b1),
                .phasecounterselect ({4{1'b1}}),
                .phasedone (),
                .phasestep (1'b1),
                .phaseupdown (1'b1),
                .pllena (1'b1),
                .scanaclr (1'b0),
                .scanclk (1'b0),
                .scanclkena (1'b1),
                .scandata (1'b0),
                .scandataout (),
                .scandone (),
                .scanread (1'b0),
                .scanwrite (1'b0),
                .sclkout0 (),
                .sclkout1 (),
                .vcooverrange (),
                .vcounderrange ());
    defparam
        altpll_component.clk0_divide_by = 15,
        altpll_component.clk0_duty_cycle = 50,
        altpll_component.clk0_multiply_by = 14,
        altpll_component.clk0_phase_shift = "0",
        altpll_component.clk1_divide_by = 3,
        altpll_component.clk1_duty_cycle = 50,
        altpll_component.clk1_multiply_by = 2,
        altpll_component.clk1_phase_shift = "0",
        altpll_component.clk2_divide_by = 15,
        altpll_component.clk2_duty_cycle = 50,
        altpll_component.clk2_multiply_by = 14,
        altpll_component.clk2_phase_shift = "-9921",
        altpll_component.compensate_clock = "CLK0",
        altpll_component.inclk0_input_frequency = 37037,
        altpll_component.intended_device_family = "Cyclone II",
        altpll_component.lpm_type = "altpll",
        altpll_component.operation_mode = "NORMAL",
        altpll_component.port_activeclock = "PORT_UNUSED",
        altpll_component.port_areset = "PORT_USED",
        altpll_component.port_clkbad0 = "PORT_UNUSED",
        altpll_component.port_clkbad1 = "PORT_UNUSED",
        altpll_component.port_clkloss = "PORT_UNUSED",
        altpll_component.port_clkswitch = "PORT_UNUSED",
        altpll_component.port_configupdate = "PORT_UNUSED",
        altpll_component.port_fbin = "PORT_UNUSED",
        altpll_component.port_inclk0 = "PORT_USED",
        altpll_component.port_inclk1 = "PORT_UNUSED",
        altpll_component.port_locked = "PORT_UNUSED",
        altpll_component.port_pfdena = "PORT_UNUSED",
        altpll_component.port_phasecounterselect = "PORT_UNUSED",
        altpll_component.port_phasedone = "PORT_UNUSED",
        altpll_component.port_phasestep = "PORT_UNUSED",
        altpll_component.port_phaseupdown = "PORT_UNUSED",
        altpll_component.port_pllena = "PORT_UNUSED",
        altpll_component.port_scanaclr = "PORT_UNUSED",
        altpll_component.port_scanclk = "PORT_UNUSED",
        altpll_component.port_scanclkena = "PORT_UNUSED",
        altpll_component.port_scandata = "PORT_UNUSED",
        altpll_component.port_scandataout = "PORT_UNUSED",
        altpll_component.port_scandone = "PORT_UNUSED",
        altpll_component.port_scanread = "PORT_UNUSED",
        altpll_component.port_scanwrite = "PORT_UNUSED",
        altpll_component.port_clk0 = "PORT_USED",
        altpll_component.port_clk1 = "PORT_USED",
        altpll_component.port_clk2 = "PORT_USED",
        altpll_component.port_clk3 = "PORT_UNUSED",
        altpll_component.port_clk4 = "PORT_UNUSED",
        altpll_component.port_clk5 = "PORT_UNUSED",
        altpll_component.port_clkena0 = "PORT_UNUSED",
        altpll_component.port_clkena1 = "PORT_UNUSED",
        altpll_component.port_clkena2 = "PORT_UNUSED",
        altpll_component.port_clkena3 = "PORT_UNUSED",
        altpll_component.port_clkena4 = "PORT_UNUSED",
        altpll_component.port_clkena5 = "PORT_UNUSED",
        altpll_component.port_extclk0 = "PORT_UNUSED",
        altpll_component.port_extclk1 = "PORT_UNUSED",
        altpll_component.port_extclk2 = "PORT_UNUSED",
        altpll_component.port_extclk3 = "PORT_UNUSED";


endmodule

// ============================================================
// CNX file retrieval info
// ============================================================
// Retrieval info: PRIVATE: ACTIVECLK_CHECK STRING "0"
// Retrieval info: PRIVATE: BANDWIDTH STRING "1.000"
// Retrieval info: PRIVATE: BANDWIDTH_FEATURE_ENABLED STRING "0"
// Retrieval info: PRIVATE: BANDWIDTH_FREQ_UNIT STRING "MHz"
// Retrieval info: PRIVATE: BANDWIDTH_PRESET STRING "Low"
// Retrieval info: PRIVATE: BANDWIDTH_USE_AUTO STRING "1"
// Retrieval info: PRIVATE: BANDWIDTH_USE_CUSTOM STRING "0"
// Retrieval info: PRIVATE: BANDWIDTH_USE_PRESET STRING "0"
// Retrieval info: PRIVATE: CLKBAD_SWITCHOVER_CHECK STRING "0"
// Retrieval info: PRIVATE: CLKLOSS_CHECK STRING "0"
// Retrieval info: PRIVATE: CLKSWITCH_CHECK STRING "1"
// Retrieval info: PRIVATE: CNX_NO_COMPENSATE_RADIO STRING "0"
// Retrieval info: PRIVATE: CREATE_CLKBAD_CHECK STRING "0"
// Retrieval info: PRIVATE: CREATE_INCLK1_CHECK STRING "0"
// Retrieval info: PRIVATE: CUR_DEDICATED_CLK STRING "c0"
// Retrieval info: PRIVATE: CUR_FBIN_CLK STRING "e0"
// Retrieval info: PRIVATE: DEVICE_SPEED_GRADE STRING "Any"
// Retrieval info: PRIVATE: DIV_FACTOR0 NUMERIC "1"
// Retrieval info: PRIVATE: DIV_FACTOR1 NUMERIC "6"
// Retrieval info: PRIVATE: DIV_FACTOR2 NUMERIC "1"
// Retrieval info: PRIVATE: DUTY_CYCLE0 STRING "50.00000000"
// Retrieval info: PRIVATE: DUTY_CYCLE1 STRING "50.00000000"
// Retrieval info: PRIVATE: DUTY_CYCLE2 STRING "50.00000000"
// Retrieval info: PRIVATE: EXPLICIT_SWITCHOVER_COUNTER STRING "0"
// Retrieval info: PRIVATE: EXT_FEEDBACK_RADIO STRING "0"
// Retrieval info: PRIVATE: GLOCKED_COUNTER_EDIT_CHANGED STRING "1"
// Retrieval info: PRIVATE: GLOCKED_FEATURE_ENABLED STRING "1"
// Retrieval info: PRIVATE: GLOCKED_MODE_CHECK STRING "0"
// Retrieval info: PRIVATE: GLOCK_COUNTER_EDIT NUMERIC "1048575"
// Retrieval info: PRIVATE: HAS_MANUAL_SWITCHOVER STRING "1"
// Retrieval info: PRIVATE: INCLK0_FREQ_EDIT STRING "27.000"
// Retrieval info: PRIVATE: INCLK0_FREQ_UNIT_COMBO STRING "MHz"
// Retrieval info: PRIVATE: INCLK1_FREQ_EDIT STRING "27.000"
// Retrieval info: PRIVATE: INCLK1_FREQ_EDIT_CHANGED STRING "1"
// Retrieval info: PRIVATE: INCLK1_FREQ_UNIT_CHANGED STRING "1"
// Retrieval info: PRIVATE: INCLK1_FREQ_UNIT_COMBO STRING "MHz"
// Retrieval info: PRIVATE: INTENDED_DEVICE_FAMILY STRING "Cyclone II"
// Retrieval info: PRIVATE: INT_FEEDBACK__MODE_RADIO STRING "1"
// Retrieval info: PRIVATE: LOCKED_OUTPUT_CHECK STRING "0"
// Retrieval info: PRIVATE: LONG_SCAN_RADIO STRING "1"
// Retrieval info: PRIVATE: LVDS_MODE_DATA_RATE STRING "Not Available"
// Retrieval info: PRIVATE: LVDS_MODE_DATA_RATE_DIRTY NUMERIC "0"
// Retrieval info: PRIVATE: LVDS_PHASE_SHIFT_UNIT0 STRING "deg"
// Retrieval info: PRIVATE: LVDS_PHASE_SHIFT_UNIT1 STRING "deg"
// Retrieval info: PRIVATE: LVDS_PHASE_SHIFT_UNIT2 STRING "ps"
// Retrieval info: PRIVATE: MIRROR_CLK0 STRING "0"
// Retrieval info: PRIVATE: MIRROR_CLK1 STRING "0"
// Retrieval info: PRIVATE: MIRROR_CLK2 STRING "0"
// Retrieval info: PRIVATE: MULT_FACTOR0 NUMERIC "1"
// Retrieval info: PRIVATE: MULT_FACTOR1 NUMERIC "5"
// Retrieval info: PRIVATE: MULT_FACTOR2 NUMERIC "1"
// Retrieval info: PRIVATE: NORMAL_MODE_RADIO STRING "1"
// Retrieval info: PRIVATE: OUTPUT_FREQ0 STRING "25.20000000"
// Retrieval info: PRIVATE: OUTPUT_FREQ1 STRING "18.00000000"
// Retrieval info: PRIVATE: OUTPUT_FREQ2 STRING "25.20000000"
// Retrieval info: PRIVATE: OUTPUT_FREQ_MODE0 STRING "1"
// Retrieval info: PRIVATE: OUTPUT_FREQ_MODE1 STRING "1"
// Retrieval info: PRIVATE: OUTPUT_FREQ_MODE2 STRING "1"
// Retrieval info: PRIVATE: OUTPUT_FREQ_UNIT0 STRING "MHz"
// Retrieval info: PRIVATE: OUTPUT_FREQ_UNIT1 STRING "MHz"
// Retrieval info: PRIVATE: OUTPUT_FREQ_UNIT2 STRING "MHz"
// Retrieval info: PRIVATE: PHASE_RECONFIG_FEATURE_ENABLED STRING "0"
// Retrieval info: PRIVATE: PHASE_RECONFIG_INPUTS_CHECK STRING "0"
// Retrieval info: PRIVATE: PHASE_SHIFT0 STRING "0.00000000"
// Retrieval info: PRIVATE: PHASE_SHIFT1 STRING "0.00000000"
// Retrieval info: PRIVATE: PHASE_SHIFT2 STRING "-90.00000000"
// Retrieval info: PRIVATE: PHASE_SHIFT_STEP_ENABLED_CHECK STRING "0"
// Retrieval info: PRIVATE: PHASE_SHIFT_UNIT0 STRING "deg"
// Retrieval info: PRIVATE: PHASE_SHIFT_UNIT1 STRING "deg"
// Retrieval info: PRIVATE: PHASE_SHIFT_UNIT2 STRING "deg"
// Retrieval info: PRIVATE: PLL_ADVANCED_PARAM_CHECK STRING "0"
// Retrieval info: PRIVATE: PLL_ARESET_CHECK STRING "1"
// Retrieval info: PRIVATE: PLL_AUTOPLL_CHECK NUMERIC "1"
// Retrieval info: PRIVATE: PLL_ENA_CHECK STRING "0"
// Retrieval info: PRIVATE: PLL_ENHPLL_CHECK NUMERIC "0"
// Retrieval info: PRIVATE: PLL_FASTPLL_CHECK NUMERIC "0"
// Retrieval info: PRIVATE: PLL_FBMIMIC_CHECK STRING "0"
// Retrieval info: PRIVATE: PLL_LVDS_PLL_CHECK NUMERIC "0"
// Retrieval info: PRIVATE: PLL_PFDENA_CHECK STRING "0"
// Retrieval info: PRIVATE: PLL_TARGET_HARCOPY_CHECK NUMERIC "0"
// Retrieval info: PRIVATE: PRIMARY_CLK_COMBO STRING "inclk0"
// Retrieval info: PRIVATE: RECONFIG_FILE STRING "VGA_Audio_PLL.mif"
// Retrieval info: PRIVATE: SACN_INPUTS_CHECK STRING "0"
// Retrieval info: PRIVATE: SCAN_FEATURE_ENABLED STRING "0"
// Retrieval info: PRIVATE: SELF_RESET_LOCK_LOSS STRING "0"
// Retrieval info: PRIVATE: SHORT_SCAN_RADIO STRING "0"
// Retrieval info: PRIVATE: SPREAD_FEATURE_ENABLED STRING "0"
// Retrieval info: PRIVATE: SPREAD_FREQ STRING "50.000"
// Retrieval info: PRIVATE: SPREAD_FREQ_UNIT STRING "KHz"
// Retrieval info: PRIVATE: SPREAD_PERCENT STRING "0.500"
// Retrieval info: PRIVATE: SPREAD_USE STRING "0"
// Retrieval info: PRIVATE: SRC_SYNCH_COMP_RADIO STRING "0"
// Retrieval info: PRIVATE: STICKY_CLK0 STRING "1"
// Retrieval info: PRIVATE: STICKY_CLK1 STRING "1"
// Retrieval info: PRIVATE: STICKY_CLK2 STRING "1"
// Retrieval info: PRIVATE: SWITCHOVER_COUNT_EDIT NUMERIC "1"
// Retrieval info: PRIVATE: SWITCHOVER_FEATURE_ENABLED STRING "1"
// Retrieval info: PRIVATE: SYNTH_WRAPPER_GEN_POSTFIX STRING "0"
// Retrieval info: PRIVATE: USE_CLK0 STRING "1"
// Retrieval info: PRIVATE: USE_CLK1 STRING "1"
// Retrieval info: PRIVATE: USE_CLK2 STRING "1"
// Retrieval info: PRIVATE: USE_CLKENA0 STRING "0"
// Retrieval info: PRIVATE: USE_CLKENA1 STRING "0"
// Retrieval info: PRIVATE: USE_CLKENA2 STRING "0"
// Retrieval info: PRIVATE: USE_MIL_SPEED_GRADE NUMERIC "0"
// Retrieval info: PRIVATE: ZERO_DELAY_RADIO STRING "0"
// Retrieval info: LIBRARY: altera_mf altera_mf.altera_mf_components.all
// Retrieval info: CONSTANT: CLK0_DIVIDE_BY NUMERIC "15"
// Retrieval info: CONSTANT: CLK0_DUTY_CYCLE NUMERIC "50"
// Retrieval info: CONSTANT: CLK0_MULTIPLY_BY NUMERIC "14"
// Retrieval info: CONSTANT: CLK0_PHASE_SHIFT STRING "0"
// Retrieval info: CONSTANT: CLK1_DIVIDE_BY NUMERIC "3"
// Retrieval info: CONSTANT: CLK1_DUTY_CYCLE NUMERIC "50"
// Retrieval info: CONSTANT: CLK1_MULTIPLY_BY NUMERIC "2"
// Retrieval info: CONSTANT: CLK1_PHASE_SHIFT STRING "0"
// Retrieval info: CONSTANT: CLK2_DIVIDE_BY NUMERIC "15"
// Retrieval info: CONSTANT: CLK2_DUTY_CYCLE NUMERIC "50"
// Retrieval info: CONSTANT: CLK2_MULTIPLY_BY NUMERIC "14"
// Retrieval info: CONSTANT: CLK2_PHASE_SHIFT STRING "-9921"
// Retrieval info: CONSTANT: COMPENSATE_CLOCK STRING "CLK0"
// Retrieval info: CONSTANT: INCLK0_INPUT_FREQUENCY NUMERIC "37037"
// Retrieval info: CONSTANT: INTENDED_DEVICE_FAMILY STRING "Cyclone II"
// Retrieval info: CONSTANT: LPM_TYPE STRING "altpll"
// Retrieval info: CONSTANT: OPERATION_MODE STRING "NORMAL"
// Retrieval info: CONSTANT: PORT_ACTIVECLOCK STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_ARESET STRING "PORT_USED"
// Retrieval info: CONSTANT: PORT_CLKBAD0 STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_CLKBAD1 STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_CLKLOSS STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_CLKSWITCH STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_CONFIGUPDATE STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_FBIN STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_INCLK0 STRING "PORT_USED"
// Retrieval info: CONSTANT: PORT_INCLK1 STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_LOCKED STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_PFDENA STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_PHASECOUNTERSELECT STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_PHASEDONE STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_PHASESTEP STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_PHASEUPDOWN STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_PLLENA STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_SCANACLR STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_SCANCLK STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_SCANCLKENA STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_SCANDATA STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_SCANDATAOUT STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_SCANDONE STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_SCANREAD STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_SCANWRITE STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_clk0 STRING "PORT_USED"
// Retrieval info: CONSTANT: PORT_clk1 STRING "PORT_USED"
// Retrieval info: CONSTANT: PORT_clk2 STRING "PORT_USED"
// Retrieval info: CONSTANT: PORT_clk3 STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_clk4 STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_clk5 STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_clkena0 STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_clkena1 STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_clkena2 STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_clkena3 STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_clkena4 STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_clkena5 STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_extclk0 STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_extclk1 STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_extclk2 STRING "PORT_UNUSED"
// Retrieval info: CONSTANT: PORT_extclk3 STRING "PORT_UNUSED"
// Retrieval info: USED_PORT: @clk 0 0 6 0 OUTPUT_CLK_EXT VCC "@clk[5..0]"
// Retrieval info: USED_PORT: @extclk 0 0 4 0 OUTPUT_CLK_EXT VCC "@extclk[3..0]"
// Retrieval info: USED_PORT: areset 0 0 0 0 INPUT GND "areset"
// Retrieval info: USED_PORT: c0 0 0 0 0 OUTPUT_CLK_EXT VCC "c0"
// Retrieval info: USED_PORT: c1 0 0 0 0 OUTPUT_CLK_EXT VCC "c1"
// Retrieval info: USED_PORT: c2 0 0 0 0 OUTPUT_CLK_EXT VCC "c2"
// Retrieval info: USED_PORT: inclk0 0 0 0 0 INPUT_CLK_EXT GND "inclk0"
// Retrieval info: CONNECT: @inclk 0 0 1 0 inclk0 0 0 0 0
// Retrieval info: CONNECT: c0 0 0 0 0 @clk 0 0 1 0
// Retrieval info: CONNECT: c1 0 0 0 0 @clk 0 0 1 1
// Retrieval info: CONNECT: c2 0 0 0 0 @clk 0 0 1 2
// Retrieval info: CONNECT: @inclk 0 0 1 1 GND 0 0 0 0
// Retrieval info: CONNECT: @areset 0 0 0 0 areset 0 0 0 0
// Retrieval info: GEN_FILE: TYPE_NORMAL VGA_Audio_PLL.v TRUE FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL VGA_Audio_PLL.inc FALSE FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL VGA_Audio_PLL.cmp FALSE FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL VGA_Audio_PLL.bsf FALSE FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL VGA_Audio_PLL_inst.v FALSE FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL VGA_Audio_PLL_bb.v FALSE FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL VGA_Audio_PLL_waveforms.html TRUE FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL VGA_Audio_PLL_wave*.jpg FALSE FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL VGA_Audio_PLL.ppf TRUE FALSE
// Retrieval info: LIB_FILE: altera_mf

module vga_sync(
   input iCLK, // 25 MHz clock
   input iRST_N,
   input [29:0] iRGB,
   // pixel coordinates
   output [9:0] px,
   output [9:0] py,
   // VGA Side
   output  [9:0] VGA_R,
   output  [9:0] VGA_G,
   output  [9:0] VGA_B,
   output reg VGA_H_SYNC,
   output reg VGA_V_SYNC,
   output VGA_SYNC,
   output VGA_BLANK
);

assign    VGA_BLANK    =    VGA_H_SYNC & VGA_V_SYNC;
assign    VGA_SYNC    =    1'b0;

reg [9:0] h_count, v_count;
assign px = h_count;
assign py = v_count;

// iRed = iRGB[29:20]; iGreen = iRGB[19:10]; iBlue = iRGB[9:0]


// Horizontal sync

/* Generate Horizontal and Vertical Timing Signals for Video Signal
* h_count counts pixels (640 + extra time for sync signals)
* 
*  horiz_sync  ------------------------------------__________--------
*  h_count       0                640             659       755    799
*/
parameter H_SYNC_TOTAL = 800;
parameter H_PIXELS =     640;
parameter H_SYNC_START = 659;
parameter H_SYNC_WIDTH =  96;

always@(posedge iCLK or negedge iRST_N)
begin
   if(!iRST_N)
   begin
      h_count <= 10'h000;
      VGA_H_SYNC <= 1'b0;
   end
   else
   begin
      // H_Sync Counter
      if (h_count < H_SYNC_TOTAL-1) h_count <= h_count + 1'b1;
      else h_count <= 10'h0000;

      if (h_count >= H_SYNC_START && 
    h_count < H_SYNC_START+H_SYNC_WIDTH) VGA_H_SYNC = 1'b0;
      else VGA_H_SYNC <= 1'b1;
   end
end
/*  
*  vertical_sync      -----------------------------------------------_______------------
*  v_count             0                                      480    493-494          524
*/
parameter V_SYNC_TOTAL = 525;
parameter V_PIXELS     = 480;
parameter V_SYNC_START = 493;
parameter V_SYNC_WIDTH =   2;
parameter H_START = 699;

always @(posedge iCLK or negedge iRST_N)
begin
   if (!iRST_N)
   begin
      v_count <= 10'h0000;
      VGA_V_SYNC <= 1'b0;
   end
   else if (h_count == H_START)
   begin
      // V_Sync Counter
      if (v_count < V_SYNC_TOTAL-1) v_count <= v_count + 1'b1;
      else v_count <= 10'h0000;

      if (v_count >= V_SYNC_START && 
        v_count < V_SYNC_START+V_SYNC_WIDTH) VGA_V_SYNC = 1'b0;
      else VGA_V_SYNC <= 1'b1;
   end
end
   

wire video_h_on = (h_count<H_PIXELS);
wire video_v_on = (v_count<V_PIXELS);
wire video_on = video_h_on & video_v_on;

assign VGA_R = (video_on? iRGB[29:20]: 10'h000);
assign VGA_G = (video_on? iRGB[19:10]: 10'h000);
assign VGA_B = (video_on? iRGB[9:0]: 10'h000);
   
endmodule

module grayscale(input [9:0] px, input [9:0] py, output [29:0] rgb);

wire [9:0] gray = (px<80 || px>560? 10'h000:
    (py/15)<<5 | (px-80)/15);
assign rgb = {gray, gray, gray};

endmodule


module bars(input [9:0] x, input [9:0] y,input [31:0]px, input [31:0]bx, input [31:0]by,
	input [26:0]bricks, output [29:0] rgb);
reg [2:0] idx;

always @(x or y)
begin
	//draw ball
	if ((x > bx) && (x < bx + 15) && (y > by) && (y < by + 15)) idx <= 3'd2;
	//Draw paddle
	else if ((x > px) && (x < px + 120) && (y > 460) && (y < 470)) idx <= 3'd2;
	//Draw bricks, 27 bricks so [26:0]
	//if ball hits brick change idx to 3'd7 which makes it white
	else if ((x > 10 & x < 70) & (y > 10 & y < 40)) begin
	    if (bricks[0] == 0) begin
		idx <= 3'd0;
	    end
	    else begin
		idx <= 3'd7;
	    end
	end
	else if ((x > 10 & x < 70)& (y > 50 & y < 80)) begin
	    if (bricks[1] == 0) begin
		idx <= 3'd0;
	    end
	    else begin
		idx <= 3'd7;
	    end
	end
	else if ((x > 10 & x < 70) & (y > 90 & y < 120)) begin
	    if (bricks[2] == 0) begin
		idx <= 3'd0;
	    end
	    else begin
		idx <= 3'd7;
	    end
	end
	else if ((x > 80 & x < 140) & (y > 10 & y < 40)) begin
	    if (bricks[3] == 0) begin
		idx <= 3'd0;
	    end
	    else begin
		idx <= 3'd7;
	    end
	end
	else if ((x > 80 & x < 140) & (y > 50 & y < 80)) begin
	    if (bricks[4] == 0) begin
		idx <= 3'd0;
	    end
	    else begin
		idx <= 3'd7;
	    end
	end
	else if ((x > 80 & x < 140) & (y > 90 & y < 120)) begin
	    if (bricks[5] == 0) begin
		idx <= 3'd0;
	    end
	    else begin
		idx <= 3'd7;
	    end
	end
	else if ((x > 150 & x < 210) & (y > 10 & y < 40)) begin
	    if (bricks[6] == 0) begin
		idx <= 3'd0;
	    end
	    else begin
		idx <= 3'd7;
	    end
	end
	else if ((x > 150 & x < 210) & (y > 50 & y < 80)) begin
	    if (bricks[7] == 0) begin
		idx <= 3'd0;
	    end
	    else begin
		idx <= 3'd7;
	    end
	end
	else if ((x > 150 & x < 210) & (y > 90 & y < 120)) begin
	    if (bricks[8] == 0) begin
		idx <= 3'd0;
	    end
	    else begin
		idx <= 3'd7;
	    end
	end
	else if ((x > 220 & x < 280) & (y > 10 & y < 40)) begin
	    if (bricks[9] == 0) begin
		idx <= 3'd0;
	    end
	    else begin
		idx <= 3'd7;
	    end
	end
	else if ((x > 220 & x < 280) & (y > 50 & y < 80)) begin
	    if (bricks[10] == 0) begin
		idx <= 3'd0;
	    end
	    else begin
		idx <= 3'd7;
	    end
	end
	else if ((x > 220 & x < 280) & (y > 90 & y < 120)) begin
	    if (bricks[11] == 0) begin
		idx <= 3'd0;
	    end
	    else begin
		idx <= 3'd7;
	    end
	end
	else if ((x > 290 & x < 350) & (y > 10 & y < 40)) begin
	    if (bricks[12] == 0) begin
		idx <= 3'd0;
	    end
	    else begin
		idx <= 3'd7;
	    end
	end
	else if ((x > 290 & x < 350) & (y > 50 & y < 80)) begin
	    if (bricks[13] == 0) begin
		idx <= 3'd0;
	    end
	    else begin
		idx <= 3'd7;
	    end
	end
	else if ((x > 290 & x < 350) & (y > 90 & y < 120)) begin
	    if (bricks[14] == 0) begin
		idx <= 3'd0;
	    end
	    else begin
		idx <= 3'd7;
	    end
	end
	else if ((x > 360 & x < 420) & (y > 10 & y < 40)) begin
	    if (bricks[15] == 0) begin
		idx <= 3'd0;
	    end
	    else begin
		idx <= 3'd7;
	    end
	end
	else if ((x > 360 & x < 420) & (y > 50 & y < 80)) begin
	    if (bricks[16] == 0) begin
		idx <= 3'd0;
	    end
	    else begin
		idx <= 3'd7;
	    end
	end
	else if ((x > 360 & x < 420) & (y > 90 & y < 120)) begin
	    if (bricks[17] == 0) begin
		idx <= 3'd0;
	    end
	    else begin
		idx <= 3'd7;
	    end
	end
	else if ((x > 430 & x < 490) & (y > 10 & y < 40)) begin
	    if (bricks[18] == 0) begin
		idx <= 3'd0;
	    end
	    else begin
		idx <= 3'd7;
	    end
	end
	else if ((x > 430 & x < 490) & (y > 50 & y < 80)) begin
	    if (bricks[19] == 0) begin
		idx <= 3'd0;
	    end
	    else begin
		idx <= 3'd7;
	    end
	end
	else if ((x > 430 & x < 490) & (y > 90 & y < 120)) begin
	    if (bricks[20] == 0) begin
		idx <= 3'd0;
	    end
	    else begin
		idx <= 3'd7;
	    end
	end
	else if ((x > 500 & x < 560) & (y > 10 & y < 40)) begin
	    if (bricks[21] == 0) begin
		idx <= 3'd0;
	    end
	    else begin
		idx <= 3'd7;
	    end
	end
	else if ((x > 500 & x < 560) & (y > 50 & y < 80)) begin
	    if (bricks[22] == 0) begin
		idx <= 3'd0;
	    end
	    else begin
		idx <= 3'd7;
	    end
	end
	else if ((x > 500 & x < 560) & (y > 90 & y < 120)) begin
	    if (bricks[23] == 0) begin
		idx <= 3'd0;
	    end
	    else begin
		idx <= 3'd7;
	    end
	end
	else if ((x > 570 & x < 630) & (y > 10 & y < 40)) begin
	    if (bricks[24] == 0) begin
		idx <= 3'd0;
	    end
	    else begin
		idx <= 3'd7;
	    end
	end
	else if ((x > 570 & x < 630) & (y > 50 & y < 80)) begin
	    if (bricks[25] == 0) begin
		idx <= 3'd0;
	    end
	    else begin
		idx <= 3'd7;
	    end
	end
	else if ((x > 570 & x < 630) & (y > 90 & y < 120)) begin
	    if (bricks[26] == 0) begin
		idx <= 3'd0;
	    end
	    else begin
		idx <= 3'd7;
	    end
	end
	//background
	else idx <= 3'd7;
end
assign rgb[29:20] = (idx[0]? 10'h3ff: 10'h000);
assign rgb[19:10] = (idx[1]? 10'h3ff: 10'h000);
assign rgb[9:0] = (idx[2]? 10'h3ff: 10'h000);

endmodule

module keyboard(keyboard_clk, keyboard_data, clock50, reset, read, scan_ready, scan_code);
input keyboard_clk;
input keyboard_data;
input clock50; // 50 Mhz system clock
input reset;
input read;
output scan_ready;
output [7:0] scan_code;
reg ready_set;
reg [7:0] scan_code;
reg scan_ready;
reg read_char;
reg clock; // 25 Mhz internal clock

reg [3:0] incnt;
reg [8:0] shiftin;

reg [7:0] filter;
reg keyboard_clk_filtered;

// scan_ready is set to 1 when scan_code is available.
// user should set read to 1 and then to 0 to clear scan_ready

always @ (posedge ready_set or posedge read)
if (read == 1) scan_ready <= 0;
else scan_ready <= 1;

// divide-by-two 50MHz to 25MHz
always @(posedge clock50)
    clock <= ~clock;


// This process filters the raw clock signal coming from the keyboard 
// using an eight-bit shift register and two AND gates

always @(posedge clock)
begin
   filter <= {keyboard_clk, filter[7:1]};
   if (filter==8'b1111_1111) keyboard_clk_filtered <= 1;
   else if (filter==8'b0000_0000) keyboard_clk_filtered <= 0;
end


// This process reads in serial data coming from the terminal

always @(posedge keyboard_clk_filtered)
begin
   if (reset==1)
   begin
      incnt <= 4'b0000;
      read_char <= 0;
   end
   else if (keyboard_data==0 && read_char==0)
   begin
    read_char <= 1;
    ready_set <= 0;
   end
   else
   begin
       // shift in next 8 data bits to assemble a scan code    
       if (read_char == 1)
           begin
              if (incnt < 9) 
              begin
                incnt <= incnt + 1'b1;
                shiftin = { keyboard_data, shiftin[8:1]};
                ready_set <= 0;
            end
        else
            begin
                incnt <= 0;
                scan_code <= shiftin[7:0];
                read_char <= 0;
                ready_set <= 1;
            end
        end
    end
end

endmodule

module oneshot(output reg pulse_out, input trigger_in, input clk);
reg delay;

always @ (posedge clk)
begin
    if (trigger_in && !delay) pulse_out <= 1'b1;
    else pulse_out <= 1'b0;
    delay <= trigger_in;
end 
endmodule

module slowclock(CLOCK_50, reset, clk);
	input CLOCK_50, reset;
	output reg clk;
	reg [25:0]Q;
	initial
		begin
		Q = 0;
		end
	always @(posedge CLOCK_50)
		begin
		if (reset)
			begin
			Q = 0;
			end
		 else if (Q == 500000)
			begin //Q == 50000000 is 1 second intervals
			Q = 0;
			clk = 1;
			end
		else
			begin
			Q = Q + 1;
			clk = 0;
			end
		end
endmodule

