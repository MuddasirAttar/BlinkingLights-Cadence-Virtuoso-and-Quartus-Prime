
module led_matrix (
    input  wire        clk50,     
    input  wire        reset_n,   
    input  wire        run,       
    output reg  [7:0]  row_n,     
    output reg  [7:0]  col        
);

    localparam MIRROR_COLS = 1;   
    localparam FLIP_ROWS   = 0;   


    wire clk0_5hz, clk500khz, clk12_5mhz;
    clockDivider u_div (
        .Clock0_5hz   (clk0_5hz),
        .Clock500Khz  (clk500khz),
        .Clock12_5Mhz (clk12_5mhz),
        .Clock50Mhz   (clk50),
        .run          (run),          
        .reset        (~reset_n)      
    );

  
    reg [7:0] row_div_cnt = 8'd0;
    reg [2:0] row_idx     = 3'd0;

    always @(posedge clk500khz or negedge reset_n) begin
        if (!reset_n) begin
            row_div_cnt <= 0;
            row_idx     <= 0;
        end else begin
            row_div_cnt <= row_div_cnt + 8'd1;
            if (row_div_cnt == 8'd255) begin
                row_div_cnt <= 0;
                row_idx     <= row_idx + 3'd1; // 0..7 roll-over
            end
        end
    end

    
    wire [2:0] row_idx_eff = FLIP_ROWS ? (3'd7 - row_idx) : row_idx;

    
    wire [7:0] row_onehot = (8'b0000_0001 << row_idx_eff);
    wire [7:0] row_drive  = ~row_onehot;

    
    reg clk0_5hz_d = 1'b0;
    always @(posedge clk50 or negedge reset_n)
        if (!reset_n) clk0_5hz_d <= 1'b0;
        else          clk0_5hz_d <= clk0_5hz;

    wire frame_tick = run & (~clk0_5hz_d & clk0_5hz);  

    localparam integer N_FRAMES = 5; 
    reg [$clog2(N_FRAMES)-1:0] frame_idx = 0;

    always @(posedge clk50 or negedge reset_n) begin
        if (!reset_n) frame_idx <= 0;
        else if (frame_tick)    frame_idx <= (frame_idx == N_FRAMES-1) ? 0 : frame_idx + 1'b1;
    end

    
    wire [7:0] cols_rom;
    hello_rom_8x8 rom_i (
        .frame_idx (frame_idx),
        .row_idx   (row_idx_eff),
        .cols      (cols_rom)
    );


    wire [7:0] cols_oriented = MIRROR_COLS
      ? {cols_rom[0],cols_rom[1],cols_rom[2],cols_rom[3],
         cols_rom[4],cols_rom[5],cols_rom[6],cols_rom[7]}
      :  cols_rom;

    
    always @(posedge clk50 or negedge reset_n) begin
        if (!reset_n) begin
            row_n <= 8'hFF; 
            col   <= 8'h00; 
        end else begin
            row_n <= row_drive;     
            col   <= cols_oriented; 
        end
    end
endmodule




module hello_rom_8x8 (
    input  wire [2:0] frame_idx,  // 0..4
    input  wire [2:0] row_idx,    // 0..7
    output reg  [7:0] cols        // active-HIGH columns for this row
);
    function automatic [7:0] G_H (input [2:0] r);
        case (r)
            3'd0: G_H = 8'b1000_0001;
            3'd1: G_H = 8'b1000_0001;
            3'd2: G_H = 8'b1111_1111;
            3'd3: G_H = 8'b1111_1111;
            3'd4: G_H = 8'b1000_0001;
            3'd5: G_H = 8'b1000_0001;
            3'd6: G_H = 8'b1000_0001;
            3'd7: G_H = 8'b0000_0000;
        endcase
    endfunction

    function automatic [7:0] G_E (input [2:0] r);
        case (r)
            3'd0: G_E = 8'b1111_1111; 
            3'd1: G_E = 8'b1000_0000; 
            3'd2: G_E = 8'b1111_1000; 
            3'd3: G_E = 8'b1000_0000; 
            3'd4: G_E = 8'b1000_0000; 
            3'd5: G_E = 8'b1111_1111; 
            3'd6: G_E = 8'b0000_0000; 
            3'd7: G_E = 8'b0000_0000;
        endcase
    endfunction

    
    function automatic [7:0] G_L (input [2:0] r);
        case (r)
            3'd0: G_L = 8'b1000_0000;
            3'd1: G_L = 8'b1000_0000;
            3'd2: G_L = 8'b1000_0000;
            3'd3: G_L = 8'b1000_0000;
            3'd4: G_L = 8'b1000_0000;
            3'd5: G_L = 8'b1111_1111; 
            3'd6: G_L = 8'b0000_0000; 
            3'd7: G_L = 8'b0000_0000;
        endcase
    endfunction

    function automatic [7:0] G_O (input [2:0] r);
        case (r)
            3'd0: G_O = 8'b0111_1110;
            3'd1: G_O = 8'b1000_0001;
            3'd2: G_O = 8'b1000_0001;
            3'd3: G_O = 8'b1000_0001;
            3'd4: G_O = 8'b1000_0001;
            3'd5: G_O = 8'b1000_0001;
            3'd6: G_O = 8'b0111_1110;
            3'd7: G_O = 8'b0000_0000;
        endcase
    endfunction

    always @* begin
        case (frame_idx)
            3'd0: cols = G_H(row_idx);
            3'd1: cols = G_E(row_idx);
            3'd2: cols = G_L(row_idx);
            3'd3: cols = G_L(row_idx);
            3'd4: cols = G_O(row_idx);
            default: cols = 8'h00;
        endcase
    end
endmodule


module clockDivider(
    output reg Clock0_5hz,
    output reg Clock500Khz,
    output reg Clock12_5Mhz,
    input Clock50Mhz,
    input run,
    input reset
);
    reg [1:0] Clock12_5Mhzctr = 0;
    initial Clock12_5Mhz = 0;
    always @(posedge Clock50Mhz) begin
        case (Clock12_5Mhzctr)
            3: begin
                Clock12_5Mhz = !Clock12_5Mhz;
                Clock12_5Mhzctr = 0;
            end
            default: Clock12_5Mhz = Clock12_5Mhz;
        endcase
        Clock12_5Mhzctr = Clock12_5Mhzctr + 1;
    end

    reg [8:0] Clock500Khzctr = 0;
    initial Clock500Khz = 0;
    always @(posedge Clock50Mhz) begin
        case (Clock500Khzctr)
            100: begin
                Clock500Khz = !Clock500Khz;
                Clock500Khzctr = 0;
            end
            default: Clock500Khz = Clock500Khz;
        endcase
        Clock500Khzctr = Clock500Khzctr + 1;
    end

    reg [25:0] Clock0_5hzCtr = 0;
    initial Clock0_5hz = 0;
    always @(posedge Clock50Mhz) begin
        case (Clock0_5hzCtr)
            25000000: begin
                Clock0_5hz = !Clock0_5hz;
                Clock0_5hzCtr = 0;
            end
            default: Clock0_5hz = Clock0_5hz;
        endcase
        Clock0_5hzCtr = Clock0_5hzCtr + 1;
    end
endmodule
