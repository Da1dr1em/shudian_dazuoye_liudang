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
//已知问题：
//1、按键响应过迟
//2、检测结果时，输入99，显示一段时间High后变成low
//3、按下按钮后系统响应过慢，大概有一两秒的样子
//fixed:
//1、2


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
// 使用临时变量计算当前猜测值
    reg [6:0] current_guess_value;


    //--------------------------------------------------------------------------
    // Local Parameters for 7-segment character codes (数码管字符编码)
    //--------------------------------------------------------------------------
    localparam C_BLANK = 6'd63;
    localparam C_0 = 6'd0; localparam C_1 = 6'd1; localparam C_2 = 6'd2; localparam C_3 = 6'd3;
    localparam C_4 = 6'd4; localparam C_5 = 6'd5; localparam C_6 = 6'd6; localparam C_7 = 6'd7;
    localparam C_8 = 6'd8; localparam C_9 = 6'd9;

    localparam C_A = 6'd10; localparam C_L = 6'd21; localparam C_P = 6'd25; localparam C_Y = 6'd34;
    localparam C_D = 6'd13; localparam C_O = 6'd24; localparam C_G = 6'd16; localparam C_U = 6'd30;
    localparam C_E = 6'd14; localparam C_S = 6'd28; localparam C_W = 6'd32; localparam C_I = 6'd18;
    localparam C_N = 6'd23; localparam C_EXCL = 6'd1; // Using '1' for '!' (感叹号用 '1' 代替)
    localparam C_H = 6'd17;
    localparam C_DASH = 6'd63; // Using BLANK for DASH (破折号用空白代替)

    localparam INITIAL_COUNTDOWN_TIME = 99; // Seconds, max 99 (初始倒计时时间，单位秒，最大99)

    //--------------------------------------------------------------------------
    // Clock Generation (for 100MHz IN_CLK) (100MHz输入时钟分频)
    //--------------------------------------------------------------------------
    reg [26:0] clk_div_counter = 0; // Up to 99,999,999 for 1Hz
    wire clk_50Hz_logic_tick;     // For main FSM logic (主FSM逻辑时钟 ~50Hz) - 提高频率
    wire clk_1Hz_countdown_tick;  // For countdown timer (倒计时时钟 ~1Hz)
    wire clk_5Hz_led_flow_tick;   // For LED flowing effect (LED流水灯时钟 ~5Hz)

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
    // Button Debouncing and Edge Detection (Active High) (按键消抖和边沿检测 - 高电平有效)
    //--------------------------------------------------------------------------
    // 创建100ms按键采样时钟
    wire clk_100ms_btn_sample_tick;
    assign clk_100ms_btn_sample_tick = ENABLE && (clk_div_counter % 27'd10_000_000 == 0); // 100MHz / 10Hz = 10,000,000

    reg [4:0] btn_raw = 5'b00000;        // 原始按键输入
    reg [4:0] btn_stable = 5'b00000;     // 消抖后的稳定状态
    reg [4:0] btn_prev = 5'b00000;       // 上一个稳定状态（用于边沿检测）
    reg [4:0] btn_edge_detected = 5'b00000; // 检测到的上升沿标志
    reg [4:0] btn_edge_consumed = 5'b00000; // 已被主逻辑处理的边沿标志
    wire [4:0] btn_pressed;              // 最终的按钮按下信号

    always @(posedge IN_CLK) begin
        if (!ENABLE) begin
            btn_raw <= 5'b00000;
            btn_stable <= 5'b00000;
            btn_prev <= 5'b00000;
            btn_edge_detected <= 5'b00000;
            btn_edge_consumed <= 5'b00000;
        end else begin
            // 每个时钟周期采样原始输入
            btn_raw <= IN_BTN;
            
            // 每100ms进行一次消抖处理
            if (clk_100ms_btn_sample_tick) begin
                // 保存上一个稳定状态用于边沿检测
                btn_prev <= btn_stable;
                
                // 直接更新稳定状态（100ms间隔足够消除抖动）
                btn_stable <= btn_raw;
                
                // 检测上升沿并设置边沿检测标志
                for (integer i = 0; i < 5; i = i + 1) begin
                    if (btn_raw[i] && !btn_stable[i]) begin
                        // 上升沿检测：当前输入为高，之前稳定状态为低
                        btn_edge_detected[i] <= 1'b1;
                    end
                end
            end
            
            // 在主逻辑时钟中处理已消费的边沿
            if (clk_50Hz_logic_tick) begin
                btn_edge_consumed <= btn_edge_detected;
                
                // 清除已被主逻辑消费的边沿标志
                for (integer i = 0; i < 5; i = i + 1) begin
                    if (btn_edge_consumed[i] && btn_edge_detected[i]) begin
                        btn_edge_detected[i] <= 1'b0;
                    end
                end
            end
        end
    end

    // 最终的按钮按下信号（当检测到边沿且尚未消费时激活）
    assign btn_pressed = ENABLE ? (btn_edge_detected & ~btn_edge_consumed) : 5'b00000;

    //--------------------------------------------------------------------------
    // Game State Machine (游戏状态机)
    //--------------------------------------------------------------------------
    localparam S_INIT             = 4'd0; // 初始
    localparam S_GEN_SECRET       = 4'd1; // 生成秘密数字
    localparam S_PROMPT_INPUT     = 4'd2; // 提示输入
    localparam S_CHECK_GUESS      = 4'd3; // 检查猜测
    localparam S_WIN_MSG          = 4'd4; // 胜利信息
    localparam S_HIGH_MSG         = 4'd5; // 猜高了信息
    localparam S_LOW_MSG          = 4'd6; // 猜低了信息
    localparam S_MSG_DELAY        = 4'd7; // 信息显示延时
    localparam S_LOSE_MSG         = 4'd8; // 失败信息

    reg [3:0] game_state = S_INIT;
    reg [3:0] game_state_next;

    //--------------------------------------------------------------------------
    // Game Variables (游戏变量)
    //--------------------------------------------------------------------------
    reg [15:0] lfsr_reg = 16'hACE1; // Fixed initial seed for LFSR (LFSR固定初始种子)
    reg [6:0] secret_number;       // Random number to guess (0-99) (要猜的秘密数字)
    reg [3:0] current_guess_d1 = 0;  // Tens digit of user's guess (用户猜测的十位数)
    reg [3:0] current_guess_d0 = 0;  // Units digit of user's guess (用户猜测的个位数)
    reg [3:0] current_guess_d1_next;
    reg [3:0] current_guess_d0_next;
    reg [6:0] user_guess_val;        // Combined user guess value (组合的用户猜测值)
    reg active_digit_is_d1 = 1'b1; // 1 for D1 (tens), 0 for D0 (units) (当前编辑的是否为十位数)
    reg active_digit_is_d1_next;

    
    reg msg_was_high = 1'b0; // 1表示之前是HIGH消息，0表示之前是LOW消息
    reg msg_was_high_next;

    reg [6:0] countdown_time_sec = INITIAL_COUNTDOWN_TIME; // Countdown timer (倒计时器)
    reg [6:0] countdown_time_sec_next;

    reg [1:0] msg_delay_count; // Counter for S_MSG_DELAY (信息显示延时计数器)
    reg [1:0] msg_delay_count_next;

    reg [15:0] led_flow_pattern = 16'h0001; // Pattern for flowing LED effect (LED流水灯模式)
    reg [15:0] led_flow_pattern_next;

    //--------------------------------------------------------------------------
    // Display data registers (显示数据寄存器)
    //--------------------------------------------------------------------------
    reg [47:0] x_display_data;    // Data for 7-segment displays (数码管显示数据)
    reg [7:0]  dp_display_data = 8'b0;    // Decimal points (小数点)
    reg [7:0]  star_control_data = 8'b0;  // For blinking specific digits (特定数字闪烁控制)
    reg [47:0] xstar_display_data;        // Data to show when blinking (闪烁时显示的数据)
    reg [15:0] current_led_output = 16'b0; // LED output (LED输出)

    //--------------------------------------------------------------------------
    // Instantiate seg7_starcontrol driver (实例化数码管闪烁驱动)
    //--------------------------------------------------------------------------
    seg7_starcontrol display_driver (
        .x(ENABLE ? x_display_data : 48'h0), // Blank display if module not enabled (模块未使能则熄灭)
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
    // Helper function to convert digit (0-9) to 7-seg code (辅助函数：数字转数码管编码)
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
    // LFSR for Random Number Generation (runs on IN_CLK) (LFSR伪随机数生成)
    //--------------------------------------------------------------------------
    always @(posedge IN_CLK) begin
        if (ENABLE) begin
            lfsr_reg <= {lfsr_reg[14:0], lfsr_reg[15] ^ lfsr_reg[13] ^ lfsr_reg[12] ^ lfsr_reg[10]};
            if (lfsr_reg == 0) lfsr_reg <= 16'hBEEF; // Re-seed if stuck at 0 (避免LFSR卡在0)
        end
    end

    //--------------------------------------------------------------------------
    // Main Game Logic (clocked by clk_50Hz_logic_tick) (主游戏逻辑)
    //--------------------------------------------------------------------------
    always @(posedge IN_CLK or negedge ENABLE) begin
        if (!ENABLE) begin // Module disabled reset (模块禁用复位)
            game_state <= S_INIT;
            current_led_output <= 16'b0;
            star_control_data <= 8'b0;
            countdown_time_sec <= INITIAL_COUNTDOWN_TIME;
            led_flow_pattern <= 16'h0001;
            current_guess_d1 <= 0;
            current_guess_d0 <= 0;
            active_digit_is_d1 <= 1'b1;
            msg_was_high <= 1'b0;
        end else if (clk_50Hz_logic_tick) begin // 更改为50Hz
            // Default assignments for next state values (下一状态默认值)
            game_state_next = game_state;
            countdown_time_sec_next = countdown_time_sec;
            msg_delay_count_next = msg_delay_count;
            led_flow_pattern_next = led_flow_pattern;
            current_guess_d1_next = current_guess_d1;
            current_guess_d0_next = current_guess_d0;
            active_digit_is_d1_next = active_digit_is_d1;
            msg_was_high_next = msg_was_high;

            // Countdown Timer Update (decrements every 1Hz) (倒计时更新，每秒减1)
            if (clk_1Hz_countdown_tick_internal_flag) begin
                if (countdown_time_sec > 0 &&
                    (game_state == S_PROMPT_INPUT || game_state == S_CHECK_GUESS )) begin
                    countdown_time_sec_next = countdown_time_sec - 1;
                end
            end

            // Game Over by Timeout Check (high priority) (超时游戏结束检查，高优先级)
            if (countdown_time_sec == 0 && countdown_time_sec_next == 0 && // Ensure it just reached zero
                (game_state == S_PROMPT_INPUT || game_state == S_CHECK_GUESS ||
                 game_state == S_HIGH_MSG || game_state == S_LOW_MSG || game_state == S_MSG_DELAY)) begin
                game_state_next = S_LOSE_MSG;
            end else begin // FSM
                case (game_state)
                    S_INIT: begin // 初始状态：显示 "PLAY"
                        x_display_data <= {C_P, C_L, C_A, C_Y, C_DASH, C_DASH, C_DASH, C_DASH};
                        xstar_display_data <= x_display_data; // No blink for PLAY (PLAY不闪烁)
                        star_control_data <= 8'b0;
                        current_led_output <= 16'b0000_0000_0000_0001; // Ready LED (准备就绪LED)
                        current_guess_d1_next = 0;
                        current_guess_d0_next = 0;
                        active_digit_is_d1_next = 1'b1; // Default to editing tens digit (默认编辑十位数)
                        countdown_time_sec_next = INITIAL_COUNTDOWN_TIME; // Reset countdown (重置倒计时)
                        led_flow_pattern_next = 16'h0001; // Reset LED flow pattern (重置流水灯模式)

                        if (btn_pressed[3]) begin // BTN3: Start Game (开始游戏)
                            game_state_next = S_GEN_SECRET;
                        end
                    end

                    S_GEN_SECRET: begin // 生成秘密数字状态：显示 "LOAD Tt"
                        x_display_data <= {C_L, C_O, C_A, C_D, C_BLANK, C_BLANK, digit_to_code(INITIAL_COUNTDOWN_TIME / 10), digit_to_code(INITIAL_COUNTDOWN_TIME % 10)};
                        current_led_output <= 16'b0000_0000_0000_0010; // Loading LED (加载中LED)
                        star_control_data <= 8'b0;

                        if (lfsr_reg[6:0] < 100) begin // Ensure 0-99 from LFSR (确保LFSR生成0-99的数)
                            //secret_number <= lfsr_reg[6:0];
                            secret_number <= 7'b0001001; //验证用。指定被猜数为09
                            game_state_next = S_PROMPT_INPUT;
                        end else game_state_next = S_GEN_SECRET;// Keep trying if LFSR value is out of range (超出范围则继续尝试)
                                           
                    end

                    S_PROMPT_INPUT: begin // 提示输入状态：显示 "GUES XY Tt"
                        current_led_output <= 16'b0000_0000_0000_0100; // Input mode LED (输入模式LED)
                        x_display_data <= {C_G, C_U, C_E, C_S,
                                           digit_to_code(current_guess_d1),
                                           digit_to_code(current_guess_d0),
                                           digit_to_code(countdown_time_sec / 10),
                                           digit_to_code(countdown_time_sec % 10)};

                        if (active_digit_is_d1) begin // Blink D4 (tens digit of guess) (闪烁猜测的十位数 - D4)
                            star_control_data <= 8'b00001000; // Corresponds to x[23:18] or display_driver's an1[0]/an2[0] if s=0
                        end else begin // Blink D3 (units digit of guess) (闪烁猜测的个位数 - D3)
                            star_control_data <= 8'b00000100; // Corresponds to x[17:12] or display_driver's an1[1]/an2[1] if s=1
                        end
                        // xstar shows blanks for blinking digits (闪烁时，对应位显示空白)
                        xstar_display_data <= {C_G, C_U, C_E, C_S, 
                                               (active_digit_is_d1 ? C_BLANK : digit_to_code(current_guess_d1)), 
                                               (active_digit_is_d1 ? digit_to_code(current_guess_d0) : C_BLANK), 
                                               digit_to_code(countdown_time_sec / 10), 
                                               digit_to_code(countdown_time_sec % 10)};


                        // BTN[0]: Toggle active guess digit (切换当前编辑的数字位)
                        if (btn_pressed[0]) active_digit_is_d1_next = ~active_digit_is_d1;

                        // BTN[1]/[2]: Increment/Decrement active digit (增加/减少当前选中的数字)
                        if (active_digit_is_d1) begin // Modifying tens digit (D1) (修改十位数)
                            if (btn_pressed[1]) current_guess_d1_next = (current_guess_d1 == 9) ? 0 : current_guess_d1 + 1;
                            if (btn_pressed[2]) current_guess_d1_next = (current_guess_d1 == 0) ? 9 : current_guess_d1 - 1;
                        end else begin // Modifying units digit (D0) (修改个位数)
                            if (btn_pressed[1]) current_guess_d0_next = (current_guess_d0 == 9) ? 0 : current_guess_d0 + 1;
                            if (btn_pressed[2]) current_guess_d0_next = (current_guess_d0 == 0) ? 9 : current_guess_d0 - 1;
                        end

                        // BTN[3]: Confirm full guess (确认完整猜测)
                        if (btn_pressed[3]) begin
                            game_state_next = S_CHECK_GUESS;
                            star_control_data <= 8'b0; // Stop blinking guess digit (停止闪烁猜测位)
                        end
                    end

                    S_CHECK_GUESS: begin // 检查猜测状态
                        
                        current_guess_value = current_guess_d1 * 10 + current_guess_d0; // 阻塞赋值立即更新
                        
                        // 仍然更新user_guess_val以保持一致性
                        user_guess_val <= current_guess_value; 
                        
                        current_led_output <= 16'b0000_0000_0000_1000; // Checking LED (检查中LED)
                        star_control_data <= 8'b0;
                        
                        // 使用计算出的当前值进行比较，而不是用寄存器值
                        if (current_guess_value == secret_number) game_state_next = S_WIN_MSG;
                        else if (current_guess_value > secret_number) game_state_next = S_HIGH_MSG;                        
                        else game_state_next = S_LOW_MSG; // current_guess_value < secret_number
             
                    end

                    S_WIN_MSG: begin // 胜利信息状态：显示 "WIN! Tt"
                        x_display_data <= {C_W, C_I, C_N, C_EXCL, C_BLANK, C_BLANK, digit_to_code(countdown_time_sec / 10), digit_to_code(countdown_time_sec % 10)};
                        star_control_data <= 8'b11110000; // Blink "WIN!" (闪烁 "WIN!")
                        xstar_display_data <= {C_BLANK,C_BLANK,C_BLANK,C_BLANK, C_BLANK, C_BLANK, digit_to_code(countdown_time_sec / 10), digit_to_code(countdown_time_sec % 10)};

                        if (clk_5Hz_led_flow_tick_internal_flag) begin // LED流水灯效果
                            led_flow_pattern_next = {led_flow_pattern[14:0], led_flow_pattern[15]}; // Rotate left
                            if (led_flow_pattern_next == 16'b0 && led_flow_pattern != 16'b0) begin // Handle case if all bits become zero
                                 led_flow_pattern_next = 16'h0001; // Restart from first LED
                            end else if (led_flow_pattern == 16'b0) begin // Should not happen if initialized to non-zero
                                 led_flow_pattern_next = 16'h0001;
                            end
                        end
                        current_led_output <= led_flow_pattern;

                        if (btn_pressed[3]) begin // BTN3: Play Again (再玩一局)
                            star_control_data <= 8'b0;
                            game_state_next = S_INIT;
                        end
                    end

                    S_HIGH_MSG: begin // 猜高了信息状态：显示 "HIGH Tt"
                        x_display_data <= {C_H, C_I, C_G, C_H, C_BLANK, C_BLANK, digit_to_code(countdown_time_sec / 10), digit_to_code(countdown_time_sec % 10)};
                        star_control_data <= 8'b0;
                        current_led_output <= 16'b0000_0001_0000_0000; // LED for HIGH (高提示LED)
                        msg_delay_count_next = 0;
                        game_state_next = S_MSG_DELAY;
                        msg_was_high_next = 1'b1; // 设置标志表明这是HIGH消息
                    end

                    S_LOW_MSG: begin // 猜低了信息状态：显示 "LOW  Tt"
                        x_display_data <= {C_L, C_O, C_W, C_BLANK, C_BLANK, C_BLANK, digit_to_code(countdown_time_sec / 10), digit_to_code(countdown_time_sec % 10)};
                        star_control_data <= 8'b0;
                        current_led_output <= 16'b0000_0010_0000_0000; // LED for LOW (低提示LED)
                        msg_delay_count_next = 0;
                        game_state_next = S_MSG_DELAY;
                        msg_was_high_next = 1'b0; // 设置标志表明这是LOW消息
                    end

                    S_MSG_DELAY: begin // 信息显示延时状态
                        // 使用msg_was_high标志决定显示哪条消息
                        if (msg_was_high)
                            x_display_data <= {C_H, C_I, C_G, C_H, C_BLANK, C_BLANK, digit_to_code(countdown_time_sec / 10), digit_to_code(countdown_time_sec % 10)};
                        else
                            x_display_data <= {C_L, C_O, C_W, C_BLANK, C_BLANK, C_BLANK, digit_to_code(countdown_time_sec / 10), digit_to_code(countdown_time_sec % 10)};
                        
                        // 根据msg_was_high保持正确的LED状态
                        if (msg_was_high)
                            current_led_output <= 16'b0000_0001_0000_0000; // LED for HIGH
                        else
                            current_led_output <= 16'b0000_0010_0000_0000; // LED for LOW

                        if (clk_1Hz_countdown_tick_internal_flag) begin // Use the 1Hz flag for delay timing
                           if (msg_delay_count < 2'd1) begin 
                               msg_delay_count_next = msg_delay_count + 1;//控制延时2s
                           end else begin
                               current_guess_d1_next = 0; // Reset guess for next attempt (重置猜测以便下次尝试)
                               current_guess_d0_next = 0;
                               active_digit_is_d1_next = 1'b1; // Default to tens digit (默认十位数)
                               game_state_next = S_PROMPT_INPUT; // Go back for another guess (返回再次猜测)
                           end
                        end
                    end

                    S_LOSE_MSG: begin // 失败信息状态：显示 "LOSE 00"
                        x_display_data <= {C_L, C_O, C_S, C_E, C_BLANK, C_BLANK, C_0, C_0};
                        star_control_data <= 8'b11110000; // Blink "LOSE" (闪烁 "LOSE")
                        xstar_display_data <= {C_BLANK,C_BLANK,C_BLANK,C_BLANK, C_BLANK, C_BLANK, C_0, C_0};
                        current_led_output <= 16'hAAAA; // Alternate LEDs for lose (失败LED交替闪烁)

                        if (btn_pressed[3]) begin // BTN3: Play Again (再玩一局)
                            star_control_data <= 8'b0;
                            game_state_next = S_INIT;
                        end
                    end
                    default: game_state_next = S_INIT;
                endcase
            end // end FSM (timeout check else)

            // Assign next state values (赋值下一状态)
            game_state <= game_state_next;
            countdown_time_sec <= countdown_time_sec_next;
            msg_delay_count <= msg_delay_count_next;
            current_guess_d1 <= current_guess_d1_next;
            current_guess_d0 <= current_guess_d0_next;
            active_digit_is_d1 <= active_digit_is_d1_next;
            msg_was_high <= msg_was_high_next;

            // Update LED pattern only if in WIN state or resetting for INIT
            // (仅在胜利状态或重置到初始状态时更新LED模式)
            if (game_state_next == S_WIN_MSG)  led_flow_pattern <= led_flow_pattern_next;
                
             else if (game_state_next == S_INIT)  led_flow_pattern <= 16'h0001; // Reset pattern on INIT
                 
            
            // (非胜利状态的LED输出在各状态内部设置)

        end // end clk_50Hz_logic_tick
    end // end always block

    // Internal tick flags for FSM consumption (FSM使用的内部时钟标志)
    // These flags are set for one IN_CLK cycle by the dividers,
    // then latched for one clk_10Hz_logic_tick cycle by this logic.
    // (这些标志由分频器置位一个IN_CLK周期，然后由以下逻辑存一个clk_10Hz_logic_tick周期)
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
