# 数电大作业
## 结构分析
1. HOME.v 顶层模块
2. M0_ModeSelecter.v 选择模块
3. M1_TestViewer.v 数字显示屏
4. M2_Counter.v 计数器(LED实现十进制转2进制)
5. M3_Timer.v 正向计时器，带暂停
6. M4_Rtimer.v 倒计时器，带定时，闪烁,LED作进度条
7. M5_GuessNumber.v 猜数字游戏

### 顶层模块
调用逻辑：
```mermaid
graph TD
    A[HOME顶层模块] --> B[时钟分频系统]
    A --> C[模式控制系统]
    A --> D[输入分发系统]
    A --> E[功能模块组]
    A --> F[输出选择系统]
    
    B --> B1[ClkDiv_100ms<br/>100ms时钟]
    B --> B2[ClkDiv_500ms<br/>500ms时钟]
    
    C --> C1[DATA_MODE控制<br/>3位模式选择]
    C --> C2[ENABLE_MODE生成<br/>8位使能信号]
    C --> C3[按键消抖逻辑<br/>100ms采样]
    
    D --> D1[DIRECT1to8_16bit UI1<br/>开关信号分发]
    D --> D2[DIRECT1to8_16bit UI2<br/>按键信号分发]
    
    E --> E1[M0_ModeSelecter]
    E --> E2[M1_TextViewer]
    E --> E3[M2_Counter]
    E --> E4[M3_timer]
    E --> E5[M4_Rtimer]
    E --> E6[M5_GuessNumber]
    
    F --> F1[MUX8to1系列<br/>输出信号选择]
```
信号流向分析
```mermaid
flowchart TD
    subgraph "输入接口"
        I1[IN_CLK - 100MHz主时钟]
        I2["IN_SWITCH[15:0] - 16位开关"]
        I3["IN_BTN[4:0] - 5位按键"]
    end
    
    subgraph "时钟分频"
        C1[ClkDiv_100ms<br/>UT0]
        C2[ClkDiv_500ms<br/>UT1]
    end
    
    subgraph "模式控制逻辑"
        M1["DATA_MODE[2:0]<br/>当前模式"]
        M2["ENABLE_MODE[7:0]<br/>模块使能"]
        M3["M0_DATA_MODE_TMP[2:0]<br/>临时模式选择"]
        M4[onTouch<br/>按键防抖]
    end
    
    subgraph "输入信号分发"
        D1[DIRECT1to8_16bit UI1<br/>开关分发]
        D2[DIRECT1to8_16bit UI2<br/>按键分发]
    end
    
    subgraph "功能模块阵列"
        F0[M0: 模式选择器]
        F1[M1: 文本显示器]
        F2[M2: 计数器]
        F3[M3: 正向计时器]
        F4[M4: 倒计时器]
        F5[M5: 猜数字游戏]
    end
    
    subgraph "输出信号选择"
        O1[MUX8to1_16bit UO1 - LED输出]
        O2[MUX8to1_7bit UO2 - SEG0数据]
        O3[MUX8to1_4bit UO3 - SEG0选择]
        O4[MUX8to1_1bit UO4 - SEG0小数点]
        O5[MUX8to1_7bit UO5 - SEG1数据]
        O6[MUX8to1_4bit UO6 - SEG1选择]
        O7[MUX8to1_1bit UO7 - SEG1小数点]
    end
    
    subgraph "输出接口"
        OUT1["OUT_LED[15:0]"]
        OUT2["OUT_SEG0DATA[6:0]"]
        OUT3["OUT_SEG0SELE[3:0]"]
        OUT4[OUT_SEG0DP]
        OUT5["OUT_SEG1DATA[6:0]"]
        OUT6["OUT_SEG1SELE[3:0]"]
        OUT7[OUT_SEG1DP]
    end
    
    I1 --> C1
    I1 --> C2
    I1 --> F0
    I1 --> F1
    I1 --> F2
    I1 --> F3
    I1 --> F4
    I1 --> F5
    
    C1 --> M4
    M1 --> M2
    M1 --> D1
    M1 --> D2
    
    I2 --> D1
    I3 --> D2
    I3 --> M4
    
    D1 --> F0
    D1 --> F1
    D1 --> F2
    D1 --> F3
    D1 --> F4
    D1 --> F5
    
    D2 --> F0
    D2 --> F1
    D2 --> F2
    D2 --> F3
    D2 --> F4
    D2 --> F5
    
    M2 --> F0
    M2 --> F1
    M2 --> F2
    M2 --> F3
    M2 --> F4
    M2 --> F5
    
    F0 --> O1
    F1 --> O1
    F2 --> O1
    F3 --> O1
    F4 --> O1
    F5 --> O1
    
    F0 --> O2
    F1 --> O2
    F2 --> O2
    F3 --> O2
    F4 --> O2
    F5 --> O2
    
    O1 --> OUT1
    O2 --> OUT2
    O3 --> OUT3
    O4 --> OUT4
    O5 --> OUT5
    O6 --> OUT6
    O7 --> OUT7
```

模式状态控制机
```mermaid
stateDiagram-v2
    [*] --> MODE_0: 系统启动
    
    MODE_0: M0_模式选择器
    MODE_1: M1_文本显示器
    MODE_2: M2_计数器
    MODE_3: M3_正向计时器
    MODE_4: M4_倒计时器
    MODE_5: M5_猜数字游戏
    
    MODE_0 --> MODE_1: BTN[4] + M0_DATA_MODE_TMP=1
    MODE_0 --> MODE_2: BTN[4] + M0_DATA_MODE_TMP=2
    MODE_0 --> MODE_3: BTN[4] + M0_DATA_MODE_TMP=3
    MODE_0 --> MODE_4: BTN[4] + M0_DATA_MODE_TMP=4
    MODE_0 --> MODE_5: BTN[4] + M0_DATA_MODE_TMP=5
    
    MODE_1 --> MODE_0: BTN[4]
    MODE_2 --> MODE_0: BTN[4]
    MODE_3 --> MODE_0: BTN[4]
    MODE_4 --> MODE_0: BTN[4]
    MODE_5 --> MODE_0: BTN[4]
    
    note right of MODE_0
        在模式选择器中:
        BTN[1]: M0_DATA_MODE_TMP++
        BTN[3]: M0_DATA_MODE_TMP--
        BTN[4]: 确认选择
    end note
```

按键控制逻辑

```mermaid
flowchart TD
    A[100ms时钟触发] --> B{onTouch状态?}
    B -->|false| C[设置onTouch=true<br/>开始处理按键]
    B -->|true| D[设置onTouch=false<br/>等待下个周期]
    
    C --> E{当前在模式0?}
    E -->|是| F[模式选择逻辑]
    E -->|否| G[返回主页逻辑]
    
    F --> H{按键检测}
    H -->|"BTN[1]"| I["M0_DATA_MODE_TMP++<br/>向上选择"]
    H -->|"BTN[3]"| J["M0_DATA_MODE_TMP--<br/>向下选择"]
    H -->|"BTN[4]"| K["DATA_MODE = M0_DATA_MODE_TMP<br/>确认进入模式"]
    H -->|无按键| L[保持当前状态]
    
    G --> M{"BTN[4]按下?"}
    M -->|是| N["DATA_MODE = 0<br/>返回模式选择"]
    M -->|否| O[保持当前模式]
    
    I --> D
    J --> D
    K --> D
    L --> D
    N --> D
    O --> D
```
输入输出多路复用

```mermaid
graph TB
    subgraph "输入分发系统"
        A["IN_SWITCH[15:0]"] --> B[DIRECT1to8_16bit UI1]
        C["IN_BTN[4:0]"] --> D[DIRECT1to8_16bit UI2]
        E["DATA_MODE[2:0]"] --> B
        E --> D
        
        B --> F["M_IN_SWITCH[0] to M_IN_SWITCH[7]"]
        D --> G["M_IN_BTN[0] to M_IN_BTN[7]"]
    end
    
    subgraph "模块阵列"
        H[M0] --> I["M_OUT_SEG0DATA[0]"]
        J[M1] --> K["M_OUT_SEG0DATA[1]"]
        L[M2] --> M["M_OUT_SEG0DATA[2]"]
        N[M3] --> O["M_OUT_SEG0DATA[3]"]
        P[M4] --> Q["M_OUT_SEG0DATA[4]"]
        R[M5] --> S["M_OUT_SEG0DATA[5]"]
    end
    
    subgraph "输出选择系统"
        T[MUX8to1_7bit UO2] --> U["OUT_SEG0DATA[6:0]"]
        V[MUX8to1_16bit UO1] --> W["OUT_LED[15:0]"]
        X["DATA_MODE[2:0]"] --> T
        X --> V
        
        I --> T
        K --> T
        M --> T
        O --> T
        Q --> T
        S --> T
    end
```
