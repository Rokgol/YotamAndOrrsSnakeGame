// System-Verilog 'written by Alex Grinshpun May 2018
// New bitmap dudy February 2025
// (c) Technion IIT, Department of Electrical Engineering 2025 



module PlayerDraw(	
					input	logic	clk,
					input	logic	resetN,
					input logic	[10:0] pixelX,// offset from top left  position 
					input logic	[10:0] pixelY,
					input logic	[10:0] newHeadX,// offset from top left  position 
					input logic	[10:0] newHeadY,
					input logic 		keypressed,
					input logic snakeLonger,
					input logic framestart,
					input	logic	InsideRectangle, //input that the pixel is within a bracket 

					output	logic	drawingRequest, //output that the pixel should be dispalyed 
					output	logic	[7:0] RGBout,  //rgb value from the bitmap 
				   output   logic	[2:0] HitEdgeCode 
 ) ;

// this is the devider used to acess the right pixel 
localparam  int OBJECT_NUMBER_OF_Y_BITS = 5;  // 2^5 = 32 
localparam  int OBJECT_NUMBER_OF_X_BITS = 6;  // 2^6 = 64 
logic	[7:0] color;
logic	[7:0] color2;
logic	[7:0] finalcolor;
localparam logic [7:0] TRANSPARENT_ENCODING = 8'hFF ;// RGB value in the bitmap representing a transparent pixel 
logic	[255:0][10:0] address;
logic[10:0] temp;
logic[8:0] partToDraw;
logic [255:0][10:0] restOfSnakeX;
logic [255:0][10:0] restOfSnakeY;
logic[7:0] snakeLength;
localparam  logic	[10:0] OBJECT_HEIGHT_Y = 10'd32;
localparam  logic	[10:0] OBJECT_WIDTH_X = 10'd32;
 logic	[10:0] HitCodeX ;// offset of Hitcode 
 logic	[10:0] HitCodeY ; 
 lpm_rom #(
    .LPM_WIDTH(8),
    .LPM_WIDTHAD(11),
	 .LPM_NUMWORDS(2048),
    .LPM_FILE("RTL/snakeBody.mif"),
	   .LPM_TYPE               ("LPM_ROM"),
      .LPM_ADDRESS_CONTROL    ("REGISTERED"), 
		.LPM_OUTDATA            ("UNREGISTERED"), 
		.AUTO_CARRY_CHAINS      ("ON"),
		.AUTO_CASCADE_BUFFERS   ("ON"),
	   .INTENDED_DEVICE_FAMILY ("Cyclone V")  
) rom_tail (
    .address(address[partToDraw]),
	 .inclock(clk),
	// .outclock(clk),
    .q(color)
);
lpm_rom #(
    .LPM_WIDTH(8),
    .LPM_WIDTHAD(11),
	 .LPM_NUMWORDS(2048),
    .LPM_FILE("RTL/snakePixelatedretry.mif"),
	   .LPM_TYPE               ("LPM_ROM"),
      .LPM_ADDRESS_CONTROL    ("REGISTERED"), 
		.LPM_OUTDATA            ("UNREGISTERED"), 
		.AUTO_CARRY_CHAINS      ("ON"),
		.AUTO_CASCADE_BUFFERS   ("ON"),
	   .INTENDED_DEVICE_FAMILY ("Cyclone V")  
) rom_head (
    .address(address[partToDraw]),
	 .inclock(clk),
	// .outclock(clk),
    .q(color2)
);
//assign HitCodeX = offsetX >> ( OBJECT_NUMBER_OF_X_BITS - 4 );	//hitedge code MSB of the offset, might be useful for special apples
//assign HitCodeY = offsetY >> ( OBJECT_NUMBER_OF_Y_BITS - 4 );	 	 
//assign address = ((OBJECT_HEIGHT_Y-offsetY)*OBJECT_WIDTH_X + offsetX);


 //logic [0:15] [0:15] [2:0] hit_colors = 
	//	  {48'o4433333333333344,     
		//	48'o4443333333333444,    
			//48'o1444333333334442, 
			//48'o1144433333344422,
			//48'o1114443333444222,
			//48'o1111444334442222,
			//48'o1111144444422222,
			//48'o1111114444222222,
			//48'o1111114444222222,
			//48'o1111144444422222,
			//48'o1111444004442222,
			//48'o1114440000444222,
			//48'o1144400000044422,
			//48'o1444000000004442,
			//48'o4440000000000444,
			//48'o4400000000000044};
 
// pipeline (ff) to get the pixel color from the array 	 

//////////--------------------------------------------------------------------------------------------------------------=
always_ff@(posedge clk or negedge resetN)
begin
	if(!resetN) begin
		RGBout <=	8'h00;
		HitEdgeCode <= 3'h0;
		snakeLength <= 8'b0;
	end

	else begin
		RGBout <= TRANSPARENT_ENCODING ; // default  
		HitEdgeCode <= 3'h0;
		if(snakeLonger) begin
			snakeLength <= snakeLength + 8'b1;
		end else begin
			snakeLength <= snakeLength;
		end
		if(framestart) begin
			for(int lenloop = snakeLength; lenloop > 0; lenloop--) begin
				restOfSnakeX[lenloop] <= restOfSnakeX[lenloop-1];
				restOfSnakeY[lenloop] <= restOfSnakeY[lenloop-1];
			end
			restOfSnakeX[0] <= newHeadX;
			restOfSnakeY[0] <= newHeadY;
		end
		//take out the snake body for loop to always_comb
		
		//Am I the snake's head? Paint me if so.	 
		RGBout <= finalcolor;
		//HitEdgeCode <= hit_colors[HitCodeY][HitCodeX];	//get hit edge code from the colors table  
	end
		
end

//////////--------------------------------------------------------------------------------------------------------------=
// decide if to draw the pixel or not 
assign drawingRequest = (RGBout != TRANSPARENT_ENCODING ) ? 1'b1 : 1'b0 ; // get optional transparent command from the bitmpap   

always_comb begin

partToDraw = 9'b100000000;


for(int n = snakeLength;  n >= 0; n--) begin
	address[n] = ((OBJECT_HEIGHT_Y-restOfSnakeY[n])*OBJECT_WIDTH_X + restOfSnakeX[n]);
	if((pixelX  > restOfSnakeX[n] ||pixelX  == restOfSnakeX[n]) &&  (pixelX < restOfSnakeX[n] + OBJECT_WIDTH_X) // math is made with SIGNED variables  
						   && (pixelY  > restOfSnakeY[n] || pixelY  == restOfSnakeY[n]) &&  (pixelY < restOfSnakeY[n] + OBJECT_HEIGHT_Y) ) begin
							 partToDraw = n;
							end
end

// generating a smiley bitmap from a MIF file

if(partToDraw == 0) begin
	finalcolor = color;
end
else if(partToDraw != 9'b100000000) begin
	finalcolor = color2;
	end
else begin
	finalcolor = TRANSPARENT_ENCODING; 
end
end
endmodule