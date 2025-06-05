`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/05/24 16:27:34
// Design Name: 
// Module Name: Backup_M5
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
//��֪���⣺
//1��������Ӧ����
//2�������ʱ������99����ʾһ��ʱ��High����low
//3�����°�ť��ϵͳ��Ӧ�����������һ���������
//fixed:
//1��2


module M5_GuessNumber(
    input            ENABLE,      // Module enable signal from HOME
    input            IN_CLK,      // System clock (100MHz)
    input      [15:0]IN_SWITCH, // Switch inputs (not used for guess)
    input      [4:0] IN_BTN,      // Button inputs (active high)
    output     [6:0] OUT_SEG0DATA, // Data for 7-seg display group 0
    output     [6:0] OUT_SEG1DATA, // Data for 7-seg display group 1
    output     [3:0] OUT_SEG0SELE, // Anode select for display group 0
    output     [3:0] OUT_SEG1SELE, // Anode select for display group 1
    output           OUT_SEG0DP,   // Decimal point for display group 0
    output           OUT_SEG1DP,   // Decimal point for display group 1
    output     [15:0]OUT_LED      // LED outputs
);
// ʹ����ʱ�������㵱ǰ�²�ֵ
    reg [6:0] current_guess_value;


    //--------------------------------------------------------------------------
    // Local Parameters for 7-segment character codes (������ַ�����)
    //--------------------------------------------------------------------------
    localparam C_BLANK = 6'd63;
    localparam C_0 = 6'd0; localparam C_1 = 6'd1; localparam C_2 = 6'd2; localparam C_3 = 6'd3;
    localparam C_4 = 6'd4; localparam C_5 = 6'd5; localparam C_6 = 6'd6; localparam C_7 = 6'd7;
    localparam C_8 = 6'd8; localparam C_9 = 6'd9;

    localparam C_A = 6'd10; localparam C_L = 6'd21; localparam C_P = 6'd25; localparam C_Y = 6'd34;
    localparam C_D = 6'd13; localparam C_O = 6'd24; localparam C_G = 6'd16; localparam C_U = 6'd30;
    localparam C_E = 6'd14; localparam C_S = 6'd28; localparam C_W = 6'd32; localparam C_I = 6'd18;
    localparam C_N = 6'd23; localparam C_EXCL = 6'd1; // Using '1' for '!' (��̾���� '1' ����)
    localparam C_H = 6'd17;
    localparam C_DASH = 6'd63; // Using BLANK for DASH (���ۺ��ÿհ״���)

    localparam INITIAL_COUNTDOWN_TIME = 99; // Seconds, max 99 (��ʼ����ʱʱ�䣬��λ�룬���99)

    //--------------------------------------------------------------------------
    // Clock Generation (for 100MHz IN_CLK) (100MHz����ʱ�ӷ�Ƶ)
    //--------------------------------------------------------------------------
    reg [26:0] clk_div_counter = 0; // Up to 99,999,999 for 1Hz
    wire clk_50Hz_logic_tick;     // For main FSM logic (��FSM�߼�ʱ�� ~50Hz) - ���Ƶ��
    wire clk_1Hz_countdown_tick;  // For countdown timer (����ʱʱ�� ~1Hz)
    wire clk_5Hz_led_flow_tick;   // For LED flowing effect (LED��ˮ��ʱ�� ~5Hz)

    // For 50Hz: 100,000,000 / 50 = 2,000,000. Pulse when counter is 1,999,999
    assign clk_50Hz_logic_tick = ENABLE && (clk_div_counter == 27'd1_999_999);
    // For 1Hz: 100,000,000 / 1 = 100,000,000. Pulse when counter is 99,999_999
    assign clk_1Hz_countdown_tick = ENABLE && (clk_div_counter == 27'd99_999_999);
    // For 5Hz: 100,000,000 / 5 = 20,000,000. Pulse when counter is 19,999,999
    assign clk_5Hz_led_flow_tick = ENABLE && (clk_div_counter == 27'd19_999_999);

    always @(posedge IN_CLK or negedge ENABLE) begin
        if (!ENABLE) begin
            clk_div_counter <= 0;
        end else begin
            if (clk_div_counter == 27'd99_999_999) begin // Reset at 1Hz period (largest period)
                clk_div_counter <= 0;
            end else begin
                clk_div_counter <= clk_div_counter + 1;
            end
        end
    end

    //--------------------------------------------------------------------------
    // Button Debouncing and Edge Detection (Active High) (���������ͱ��ؼ�� - �ߵ�ƽ��Ч)
    //--------------------------------------------------------------------------
    // ����100ms��������ʱ��
    wire clk_100ms_btn_sample_tick;
    assign clk_100ms_btn_sample_tick = ENABLE && (clk_div_counter % 27'd10_000_000 == 0); // 100MHz / 10Hz = 10,000,000

    reg [4:0] btn_raw = 5'b00000;        // ԭʼ��������
    reg [4:0] btn_stable = 5'b00000;     // ��������ȶ�״̬
    reg [4:0] btn_prev = 5'b00000;       // ��һ���ȶ�״̬�����ڱ��ؼ�⣩
    reg [4:0] btn_edge_detected = 5'b00000; // ��⵽�������ر�־
    reg [4:0] btn_edge_consumed = 5'b00000; // �ѱ����߼�����ı��ر�־
    wire [4:0] btn_pressed;              // ���յİ�ť�����ź�

    always @(posedge IN_CLK) begin
        if (!ENABLE) begin
            btn_raw <= 5'b00000;
            btn_stable <= 5'b00000;
            btn_prev <= 5'b00000;
            btn_edge_detected <= 5'b00000;
            btn_edge_consumed <= 5'b00000;
        end else begin
            // ÿ��ʱ�����ڲ���ԭʼ����
            btn_raw <= IN_BTN;
            
            // ÿ100ms����һ����������
            if (clk_100ms_btn_sample_tick) begin
                // ������һ���ȶ�״̬���ڱ��ؼ��
                btn_prev <= btn_stable;
                
                // ֱ�Ӹ����ȶ�״̬��100ms����㹻����������
                btn_stable <= btn_raw;
                
                // ��������ز����ñ��ؼ���־
                for (integer i = 0; i < 5; i = i + 1) begin
                    if (btn_raw[i] && !btn_stable[i]) begin
                        // �����ؼ�⣺��ǰ����Ϊ�ߣ�֮ǰ�ȶ�״̬Ϊ��
                        btn_edge_detected[i] <= 1'b1;
                    end
                end
            end
            
            // �����߼�ʱ���д��������ѵı���
            if (clk_50Hz_logic_tick) begin
                btn_edge_consumed <= btn_edge_detected;
                
                // ����ѱ����߼����ѵı��ر�־
                for (integer i = 0; i < 5; i = i + 1) begin
                    if (btn_edge_consumed[i] && btn_edge_detected[i]) begin
                        btn_edge_detected[i] <= 1'b0;
                    end
                end
            end
        end
    end

    // ���յİ�ť�����źţ�����⵽��������δ����ʱ���
    assign btn_pressed = ENABLE ? (btn_edge_detected & ~btn_edge_consumed) : 5'b00000;

    //--------------------------------------------------------------------------
    // Game State Machine (��Ϸ״̬��)
    //--------------------------------------------------------------------------
    localparam S_INIT             = 4'd0; // ��ʼ
    localparam S_GEN_SECRET       = 4'd1; // ������������
    localparam S_PROMPT_INPUT     = 4'd2; // ��ʾ����
    localparam S_CHECK_GUESS      = 4'd3; // ���²�
    localparam S_WIN_MSG          = 4'd4; // ʤ����Ϣ
    localparam S_HIGH_MSG         = 4'd5; // �¸�����Ϣ
    localparam S_LOW_MSG          = 4'd6; // �µ�����Ϣ
    localparam S_MSG_DELAY        = 4'd7; // ��Ϣ��ʾ��ʱ
    localparam S_LOSE_MSG         = 4'd8; // ʧ����Ϣ

    reg [3:0] game_state = S_INIT;
    reg [3:0] game_state_next;

    //--------------------------------------------------------------------------
    // Game Variables (��Ϸ����)
    //--------------------------------------------------------------------------
    reg [15:0] lfsr_reg = 16'hACE1; // Fixed initial seed for LFSR (LFSR�̶���ʼ����)
    reg [6:0] secret_number;       // Random number to guess (0-99) (Ҫ�µ���������)
    reg [3:0] current_guess_d1 = 0;  // Tens digit of user's guess (�û��²��ʮλ��)
    reg [3:0] current_guess_d0 = 0;  // Units digit of user's guess (�û��²�ĸ�λ��)
    reg [3:0] current_guess_d1_next;
    reg [3:0] current_guess_d0_next;
    reg [6:0] user_guess_val;        // Combined user guess value (��ϵ��û��²�ֵ)
    reg active_digit_is_d1 = 1'b1; // 1 for D1 (tens), 0 for D0 (units) (��ǰ�༭���Ƿ�Ϊʮλ��)
    reg active_digit_is_d1_next;

    
    reg msg_was_high = 1'b0; // 1��ʾ֮ǰ��HIGH��Ϣ��0��ʾ֮ǰ��LOW��Ϣ
    reg msg_was_high_next;

    reg [6:0] countdown_time_sec = INITIAL_COUNTDOWN_TIME; // Countdown timer (����ʱ��)
    reg [6:0] countdown_time_sec_next;

    reg [1:0] msg_delay_count; // Counter for S_MSG_DELAY (��Ϣ��ʾ��ʱ������)
    reg [1:0] msg_delay_count_next;

    reg [15:0] led_flow_pattern = 16'h0001; // Pattern for flowing LED effect (LED��ˮ��ģʽ)
    reg [15:0] led_flow_pattern_next;

    //--------------------------------------------------------------------------
    // Display data registers (��ʾ���ݼĴ���)
    //--------------------------------------------------------------------------
    reg [47:0] x_display_data;    // Data for 7-segment displays (�������ʾ����)
    reg [7:0]  dp_display_data = 8'b0;    // Decimal points (С����)
    reg [7:0]  star_control_data = 8'b0;  // For blinking specific digits (�ض�������˸����)
    reg [47:0] xstar_display_data;        // Data to show when blinking (��˸ʱ��ʾ������)
    reg [15:0] current_led_output = 16'b0; // LED output (LED���)

    //--------------------------------------------------------------------------
    // Instantiate seg7_starcontrol driver (ʵ�����������˸����)
    //--------------------------------------------------------------------------
    seg7_starcontrol display_driver (
        .x(ENABLE ? x_display_data : 48'h0), // Blank display if module not enabled (ģ��δʹ����Ϩ��)
        .xstar(xstar_display_data),
        .dp(dp_display_data),
        .dpstar(8'b0), 
        .star(ENABLE ? star_control_data : 8'b0),
        .clk(IN_CLK),
        .a_to_g1(OUT_SEG0DATA), .an1(OUT_SEG0SELE), .dp1(OUT_SEG0DP),
        .a_to_g2(OUT_SEG1DATA), .an2(OUT_SEG1SELE), .dp2(OUT_SEG1DP)
    );
    assign OUT_LED = ENABLE ? current_led_output : 16'b0;

    //--------------------------------------------------------------------------
    // Helper function to convert digit (0-9) to 7-seg code (��������������ת����ܱ���)
    //--------------------------------------------------------------------------
    function [5:0] digit_to_code;
        input [3:0] digit;
        case (digit)
            0: digit_to_code = C_0; 1: digit_to_code = C_1; 2: digit_to_code = C_2;
            3: digit_to_code = C_3; 4: digit_to_code = C_4; 5: digit_to_code = C_5;
            6: digit_to_code = C_6; 7: digit_to_code = C_7; 8: digit_to_code = C_8;
            9: digit_to_code = C_9;
            default: digit_to_code = C_BLANK;
        endcase
    endfunction

    //--------------------------------------------------------------------------
    // LFSR for Random Number Generation (runs on IN_CLK) (LFSRα���������)
    //--------------------------------------------------------------------------
    always @(posedge IN_CLK) begin
        if (ENABLE) begin
            lfsr_reg <= {lfsr_reg[14:0], lfsr_reg[15] ^ lfsr_reg[13] ^ lfsr_reg[12] ^ lfsr_reg[10]};
            if (lfsr_reg == 0) lfsr_reg <= 16'hBEEF; // Re-seed if stuck at 0 (����LFSR����0)
        end
    end

    //--------------------------------------------------------------------------
    // Main Game Logic (clocked by clk_50Hz_logic_tick) (����Ϸ�߼�)
    //--------------------------------------------------------------------------
    always @(posedge IN_CLK or negedge ENABLE) begin
        if (!ENABLE) begin // Module disabled reset (ģ����ø�λ)
            game_state <= S_INIT;
            current_led_output <= 16'b0;
            star_control_data <= 8'b0;
            countdown_time_sec <= INITIAL_COUNTDOWN_TIME;
            led_flow_pattern <= 16'h0001;
            current_guess_d1 <= 0;
            current_guess_d0 <= 0;
            active_digit_is_d1 <= 1'b1;
            msg_was_high <= 1'b0;
        end else if (clk_50Hz_logic_tick) begin // ����Ϊ50Hz
            // Default assignments for next state values (��һ״̬Ĭ��ֵ)
            game_state_next = game_state;
            countdown_time_sec_next = countdown_time_sec;
            msg_delay_count_next = msg_delay_count;
            led_flow_pattern_next = led_flow_pattern;
            current_guess_d1_next = current_guess_d1;
            current_guess_d0_next = current_guess_d0;
            active_digit_is_d1_next = active_digit_is_d1;
            msg_was_high_next = msg_was_high;

            // Countdown Timer Update (decrements every 1Hz) (����ʱ���£�ÿ���1)
            if (clk_1Hz_countdown_tick_internal_flag) begin
                if (countdown_time_sec > 0 &&
                    (game_state == S_PROMPT_INPUT || game_state == S_CHECK_GUESS )) begin
                    countdown_time_sec_next = countdown_time_sec - 1;
                end
            end

            // Game Over by Timeout Check (high priority) (��ʱ��Ϸ������飬�����ȼ�)
            if (countdown_time_sec == 0 && countdown_time_sec_next == 0 && // Ensure it just reached zero
                (game_state == S_PROMPT_INPUT || game_state == S_CHECK_GUESS ||
                 game_state == S_HIGH_MSG || game_state == S_LOW_MSG || game_state == S_MSG_DELAY)) begin
                game_state_next = S_LOSE_MSG;
            end else begin // FSM
                case (game_state)
                    S_INIT: begin // ��ʼ״̬����ʾ "PLAY"
                        x_display_data <= {C_P, C_L, C_A, C_Y, C_DASH, C_DASH, C_DASH, C_DASH};
                        xstar_display_data <= x_display_data; // No blink for PLAY (PLAY����˸)
                        star_control_data <= 8'b0;
                        current_led_output <= 16'b0000_0000_0000_0001; // Ready LED (׼������LED)
                        current_guess_d1_next = 0;
                        current_guess_d0_next = 0;
                        active_digit_is_d1_next = 1'b1; // Default to editing tens digit (Ĭ�ϱ༭ʮλ��)
                        countdown_time_sec_next = INITIAL_COUNTDOWN_TIME; // Reset countdown (���õ���ʱ)
                        led_flow_pattern_next = 16'h0001; // Reset LED flow pattern (������ˮ��ģʽ)

                        if (btn_pressed[3]) begin // BTN3: Start Game (��ʼ��Ϸ)
                            game_state_next = S_GEN_SECRET;
                        end
                    end

                    S_GEN_SECRET: begin // ������������״̬����ʾ "LOAD Tt"
                        x_display_data <= {C_L, C_O, C_A, C_D, C_BLANK, C_BLANK, digit_to_code(INITIAL_COUNTDOWN_TIME / 10), digit_to_code(INITIAL_COUNTDOWN_TIME % 10)};
                        current_led_output <= 16'b0000_0000_0000_0010; // Loading LED (������LED)
                        star_control_data <= 8'b0;

                        if (lfsr_reg[6:0] < 100) begin // Ensure 0-99 from LFSR (ȷ��LFSR����0-99����)
                            //secret_number <= lfsr_reg[6:0];
                            secret_number <= 7'b0001001; //��֤�á�ָ��������Ϊ09
                            game_state_next = S_PROMPT_INPUT;
                        end else game_state_next = S_GEN_SECRET;// Keep trying if LFSR value is out of range (������Χ���������)
                                           
                    end

                    S_PROMPT_INPUT: begin // ��ʾ����״̬����ʾ "GUES XY Tt"
                        current_led_output <= 16'b0000_0000_0000_0100; // Input mode LED (����ģʽLED)
                        x_display_data <= {C_G, C_U, C_E, C_S,
                                           digit_to_code(current_guess_d1),
                                           digit_to_code(current_guess_d0),
                                           digit_to_code(countdown_time_sec / 10),
                                           digit_to_code(countdown_time_sec % 10)};

                        if (active_digit_is_d1) begin // Blink D4 (tens digit of guess) (��˸�²��ʮλ�� - D4)
                            star_control_data <= 8'b00001000; // Corresponds to x[23:18] or display_driver's an1[0]/an2[0] if s=0
                        end else begin // Blink D3 (units digit of guess) (��˸�²�ĸ�λ�� - D3)
                            star_control_data <= 8'b00000100; // Corresponds to x[17:12] or display_driver's an1[1]/an2[1] if s=1
                        end
                        // xstar shows blanks for blinking digits (��˸ʱ����Ӧλ��ʾ�հ�)
                        xstar_display_data <= {C_G, C_U, C_E, C_S, 
                                               (active_digit_is_d1 ? C_BLANK : digit_to_code(current_guess_d1)), 
                                               (active_digit_is_d1 ? digit_to_code(current_guess_d0) : C_BLANK), 
                                               digit_to_code(countdown_time_sec / 10), 
                                               digit_to_code(countdown_time_sec % 10)};


                        // BTN[0]: Toggle active guess digit (�л���ǰ�༭������λ)
                        if (btn_pressed[0]) active_digit_is_d1_next = ~active_digit_is_d1;

                        // BTN[1]/[2]: Increment/Decrement active digit (����/���ٵ�ǰѡ�е�����)
                        if (active_digit_is_d1) begin // Modifying tens digit (D1) (�޸�ʮλ��)
                            if (btn_pressed[1]) current_guess_d1_next = (current_guess_d1 == 9) ? 0 : current_guess_d1 + 1;
                            if (btn_pressed[2]) current_guess_d1_next = (current_guess_d1 == 0) ? 9 : current_guess_d1 - 1;
                        end else begin // Modifying units digit (D0) (�޸ĸ�λ��)
                            if (btn_pressed[1]) current_guess_d0_next = (current_guess_d0 == 9) ? 0 : current_guess_d0 + 1;
                            if (btn_pressed[2]) current_guess_d0_next = (current_guess_d0 == 0) ? 9 : current_guess_d0 - 1;
                        end

                        // BTN[3]: Confirm full guess (ȷ�������²�)
                        if (btn_pressed[3]) begin
                            game_state_next = S_CHECK_GUESS;
                            star_control_data <= 8'b0; // Stop blinking guess digit (ֹͣ��˸�²�λ)
                        end
                    end

                    S_CHECK_GUESS: begin // ���²�״̬
                        
                        current_guess_value = current_guess_d1 * 10 + current_guess_d0; // ������ֵ��������
                        
                        // ��Ȼ����user_guess_val�Ա���һ����
                        user_guess_val <= current_guess_value; 
                        
                        current_led_output <= 16'b0000_0000_0000_1000; // Checking LED (�����LED)
                        star_control_data <= 8'b0;
                        
                        // ʹ�ü�����ĵ�ǰֵ���бȽϣ��������üĴ���ֵ
                        if (current_guess_value == secret_number) game_state_next = S_WIN_MSG;
                        else if (current_guess_value > secret_number) game_state_next = S_HIGH_MSG;                        
                        else game_state_next = S_LOW_MSG; // current_guess_value < secret_number
             
                    end

                    S_WIN_MSG: begin // ʤ����Ϣ״̬����ʾ "WIN! Tt"
                        x_display_data <= {C_W, C_I, C_N, C_EXCL, C_BLANK, C_BLANK, digit_to_code(countdown_time_sec / 10), digit_to_code(countdown_time_sec % 10)};
                        star_control_data <= 8'b11110000; // Blink "WIN!" (��˸ "WIN!")
                        xstar_display_data <= {C_BLANK,C_BLANK,C_BLANK,C_BLANK, C_BLANK, C_BLANK, digit_to_code(countdown_time_sec / 10), digit_to_code(countdown_time_sec % 10)};

                        if (clk_5Hz_led_flow_tick_internal_flag) begin // LED��ˮ��Ч��
                            led_flow_pattern_next = {led_flow_pattern[14:0], led_flow_pattern[15]}; // Rotate left
                            if (led_flow_pattern_next == 16'b0 && led_flow_pattern != 16'b0) begin // Handle case if all bits become zero
                                 led_flow_pattern_next = 16'h0001; // Restart from first LED
                            end else if (led_flow_pattern == 16'b0) begin // Should not happen if initialized to non-zero
                                 led_flow_pattern_next = 16'h0001;
                            end
                        end
                        current_led_output <= led_flow_pattern;

                        if (btn_pressed[3]) begin // BTN3: Play Again (����һ��)
                            star_control_data <= 8'b0;
                            game_state_next = S_INIT;
                        end
                    end

                    S_HIGH_MSG: begin // �¸�����Ϣ״̬����ʾ "HIGH Tt"
                        x_display_data <= {C_H, C_I, C_G, C_H, C_BLANK, C_BLANK, digit_to_code(countdown_time_sec / 10), digit_to_code(countdown_time_sec % 10)};
                        star_control_data <= 8'b0;
                        current_led_output <= 16'b0000_0001_0000_0000; // LED for HIGH (����ʾLED)
                        msg_delay_count_next = 0;
                        game_state_next = S_MSG_DELAY;
                        msg_was_high_next = 1'b1; // ���ñ�־��������HIGH��Ϣ
                    end

                    S_LOW_MSG: begin // �µ�����Ϣ״̬����ʾ "LOW  Tt"
                        x_display_data <= {C_L, C_O, C_W, C_BLANK, C_BLANK, C_BLANK, digit_to_code(countdown_time_sec / 10), digit_to_code(countdown_time_sec % 10)};
                        star_control_data <= 8'b0;
                        current_led_output <= 16'b0000_0010_0000_0000; // LED for LOW (����ʾLED)
                        msg_delay_count_next = 0;
                        game_state_next = S_MSG_DELAY;
                        msg_was_high_next = 1'b0; // ���ñ�־��������LOW��Ϣ
                    end

                    S_MSG_DELAY: begin // ��Ϣ��ʾ��ʱ״̬
                        // ʹ��msg_was_high��־������ʾ������Ϣ
                        if (msg_was_high)
                            x_display_data <= {C_H, C_I, C_G, C_H, C_BLANK, C_BLANK, digit_to_code(countdown_time_sec / 10), digit_to_code(countdown_time_sec % 10)};
                        else
                            x_display_data <= {C_L, C_O, C_W, C_BLANK, C_BLANK, C_BLANK, digit_to_code(countdown_time_sec / 10), digit_to_code(countdown_time_sec % 10)};
                        
                        // ����msg_was_high������ȷ��LED״̬
                        if (msg_was_high)
                            current_led_output <= 16'b0000_0001_0000_0000; // LED for HIGH
                        else
                            current_led_output <= 16'b0000_0010_0000_0000; // LED for LOW

                        if (clk_1Hz_countdown_tick_internal_flag) begin // Use the 1Hz flag for delay timing
                           if (msg_delay_count < 2'd1) begin 
                               msg_delay_count_next = msg_delay_count + 1;//������ʱ2s
                           end else begin
                               current_guess_d1_next = 0; // Reset guess for next attempt (���ò²��Ա��´γ���)
                               current_guess_d0_next = 0;
                               active_digit_is_d1_next = 1'b1; // Default to tens digit (Ĭ��ʮλ��)
                               game_state_next = S_PROMPT_INPUT; // Go back for another guess (�����ٴβ²�)
                           end
                        end
                    end

                    S_LOSE_MSG: begin // ʧ����Ϣ״̬����ʾ "LOSE 00"
                        x_display_data <= {C_L, C_O, C_S, C_E, C_BLANK, C_BLANK, C_0, C_0};
                        star_control_data <= 8'b11110000; // Blink "LOSE" (��˸ "LOSE")
                        xstar_display_data <= {C_BLANK,C_BLANK,C_BLANK,C_BLANK, C_BLANK, C_BLANK, C_0, C_0};
                        current_led_output <= 16'hAAAA; // Alternate LEDs for lose (ʧ��LED������˸)

                        if (btn_pressed[3]) begin // BTN3: Play Again (����һ��)
                            star_control_data <= 8'b0;
                            game_state_next = S_INIT;
                        end
                    end
                    default: game_state_next = S_INIT;
                endcase
            end // end FSM (timeout check else)

            // Assign next state values (��ֵ��һ״̬)
            game_state <= game_state_next;
            countdown_time_sec <= countdown_time_sec_next;
            msg_delay_count <= msg_delay_count_next;
            current_guess_d1 <= current_guess_d1_next;
            current_guess_d0 <= current_guess_d0_next;
            active_digit_is_d1 <= active_digit_is_d1_next;
            msg_was_high <= msg_was_high_next;

            // Update LED pattern only if in WIN state or resetting for INIT
            // (����ʤ��״̬�����õ���ʼ״̬ʱ����LEDģʽ)
            if (game_state_next == S_WIN_MSG)  led_flow_pattern <= led_flow_pattern_next;
                
             else if (game_state_next == S_INIT)  led_flow_pattern <= 16'h0001; // Reset pattern on INIT
                 
            
            // (��ʤ��״̬��LED����ڸ�״̬�ڲ�����)

        end // end clk_50Hz_logic_tick
    end // end always block

    // Internal tick flags for FSM consumption (FSMʹ�õ��ڲ�ʱ�ӱ�־)
    // These flags are set for one IN_CLK cycle by the dividers,
    // then latched for one clk_10Hz_logic_tick cycle by this logic.
    // (��Щ��־�ɷ�Ƶ����λһ��IN_CLK���ڣ�Ȼ���������߼���һ��clk_10Hz_logic_tick����)
    reg clk_1Hz_countdown_tick_internal_flag = 0;
    reg clk_5Hz_led_flow_tick_internal_flag = 0;

    always @(posedge IN_CLK) begin
        if (!ENABLE) begin
            clk_1Hz_countdown_tick_internal_flag <= 0;
            clk_5Hz_led_flow_tick_internal_flag <= 0;
        end else begin
            // Set flag on the actual tick from divider
            if (clk_1Hz_countdown_tick) clk_1Hz_countdown_tick_internal_flag <= 1'b1;
            if (clk_5Hz_led_flow_tick)  clk_5Hz_led_flow_tick_internal_flag  <= 1'b1;

            // Clear flag after it has been seen by the 10Hz FSM logic tick
            // This ensures the FSM sees the tick for one of its cycles.
            if (clk_50Hz_logic_tick) begin
                if (clk_1Hz_countdown_tick_internal_flag) clk_1Hz_countdown_tick_internal_flag <= 1'b0;
                if (clk_5Hz_led_flow_tick_internal_flag)  clk_5Hz_led_flow_tick_internal_flag  <= 1'b0;
            end
        end
    end

endmodule
