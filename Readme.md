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
    A[HOME顶层模块]
    A --> C[模式控制系统]
    A --> D[输入分发系统]
    A --> E[功能模块组]
 

    
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
### 数码管显示驱动程序
逻辑结构图
```mermaid
flowchart TD
    subgraph "输入接口"
        A["x[47:0] - 48位数据<br/>8个字符×6位编码"]
        B["dp[7:0] - 8位小数点控制"]
        C[clk - 时钟输入]
    end
    
    subgraph "时钟分频与扫描控制"
        D[clkdiv计数器<br/>20位]
        E["s = clkdiv[19:18]<br/>2位扫描选择"]
        F[扫描频率<br/>约48Hz切换]
    end
    
    subgraph "字符数据映射"
        G["扫描选择逻辑<br/>4:1 MUX"]
        H["digit1[5:0]<br/>左半数码管字符"]
        I["digit2[5:0]<br/>右半数码管字符"]
        J["dp1, dp2<br/>对应小数点"]
    end
    
    subgraph "字符编码转换"
        K["digit1解码器<br/>6bit→7bit"]
        L["digit2解码器<br/>6bit→7bit"]
        M["字符库<br/>数字+字母+符号"]
    end
    
    subgraph "位选控制"
        N["aen使能信号<br/>4'b1111"]
        O["an1[3:0]位选输出1"]
        P["an2[3:0]位选输出2"]
    end
    
    subgraph "输出接口"
        Q["a_to_g1[6:0]<br/>左半7段码"]
        R["a_to_g2[6:0]<br/>右半7段码"]
        S[dp1 - 左半小数点]
        T[dp2 - 右半小数点]
        U["an1[3:0] - 左半位选"]
        V["an2[3:0] - 右半位选"]
    end
    
    C --> D
    D --> E
    E --> F
    A --> G
    B --> G
    E --> G
    G --> H
    G --> I
    G --> J
    H --> K
    I --> L
    K --> M
    L --> M
    M --> Q
    M --> R
    J --> S
    J --> T
    N --> O
    N --> P
    O --> U
    P --> V
```
数据映射扫描逻辑
```mermaid
flowchart LR
    subgraph "48位输入数据布局"
        A["x[47:42] - 第8位字符"]
        B["x[41:36] - 第7位字符"]
        C["x[35:30] - 第6位字符"]
        D["x[29:24] - 第5位字符"]
        E["x[23:18] - 第4位字符"]
        F["x[17:12] - 第3位字符"]
        G["x[11:6] - 第2位字符"]
        H["x[5:0] - 第1位字符"]
    end
    
    subgraph "扫描时序控制"
        I["s=00: 显示位8,4<br/>每个扫描周期约20ms"]
        J["s=01: 显示位7,3"]
        K["s=10: 显示位6,2"]
        L["s=11: 显示位5,1"]
    end
    
    subgraph "输出映射"
        M[digit1 → 左半数码管]
        N[digit2 → 右半数码管]
    end
    
    I --> A
    I --> E
    J --> B
    J --> F
    K --> C
    K --> G
    L --> D
    L --> H
    
    A --> M
    E --> N
    B --> M
    F --> N
    C --> M
    G --> N
    D --> M
    H --> N
```
字符编码表
```mermaid
graph TB
    subgraph "数字编码 (0-9)"
        A["0→7'b0111111<br/>1→7'b0000110<br/>2→7'b1011011<br/>..."]
    end
    
    subgraph "字母编码 (A-Z)"
        B["A(10)→7'b1110111<br/>B(11)→7'b1111100<br/>C(12)→7'b0111001<br/>...<br/>Z(35)→7'b1011011"]
    end
    
    subgraph "特殊符号"
        C["空白(63)→7'b0000000<br/>横线(default)→7'b1000000<br/>单段亮(36-42)→特定段"]
    end
    
    subgraph "7段显示格式"
        D[" a<br/>f b<br/> g<br/>e c<br/> d"]
    end
    
    A --> D
    B --> D
    C --> D
```

时序控制分析

```mermaid
timeline
    title 扫描时序图 (基于100MHz时钟)
    
    section 时钟分频
        t=0          : clkdiv[19:18] = 00
                     : 显示第8,4位字符
        t=2.6ms      : clkdiv[19:18] = 01  
                     : 显示第7,3位字符
        t=5.2ms      : clkdiv[19:18] = 10
                     : 显示第6,2位字符  
        t=7.8ms      : clkdiv[19:18] = 11
                     : 显示第5,1位字符
        t=10.5ms     : 循环回到00
                     : 完整扫描周期
    
    section 用户感知
        t=0~10.5ms   : 人眼积分效应
                     : 看到8位同时显示
```
#### 闪烁控制逻辑
```mermaid
flowchart TD
    subgraph "输入接口"
        A["x[47:0] - 正常显示内容"]
        B["xstar[47:0] - 闪烁显示内容"]
        C["dp[7:0] - 正常小数点"]
        D["dpstar[7:0] - 闪烁小数点"]
        E["star[7:0] - 闪烁位选择"]
        F[clk - 100MHz时钟]
    end
    
    subgraph "闪烁时钟生成"
        G[27位分频计数器<br/>clkdiv]
        H[1Hz闪烁控制<br/>onstar]
        I[50,000,000计数阈值<br/>0.5秒翻转]
    end
    
    subgraph "内容选择逻辑"
        J[闪烁状态判断<br/>onstar状态]
        K[8位独立选择器<br/>每位6bit内容]
        L[小数点选择器<br/>8位独立控制]
        M["newx[47:0] - 处理后内容"]
        N["newdp[7:0] - 处理后小数点"]
    end
    
    subgraph "状态输出"
        O["staring[7:0] - 闪烁状态指示<br/>onstar & star[i]"]
    end
    
    subgraph "seg7基础显示模块"
        P[seg7实例<br/>基础扫描显示]
        Q[字符编码转换]
        R[扫描时序控制]
    end
    
    subgraph "输出接口"
        S["a_to_g1[6:0] - 左半7段码"]
        T["a_to_g2[6:0] - 右半7段码"]
        U["an1[3:0] - 左半位选"]
        V["an2[3:0] - 右半位选"]
        W[dp1 - 左半小数点]
        X[dp2 - 右半小数点]
    end
    
    F --> G
    G --> H
    H --> I
    
    A --> J
    B --> J
    C --> J
    D --> J
    E --> J
    H --> J
    
    J --> K
    J --> L
    K --> M
    L --> N
    
    H --> O
    E --> O
    
    M --> P
    N --> P
    F --> P
    
    P --> Q
    P --> R
    Q --> S
    Q --> T
    R --> U
    R --> V
    P --> W
    P --> X
```

### 模块0——模式选择器
逻辑结构图
```mermaid
flowchart TD
    subgraph "M0_ModeSelecter模式选择器"
        A[data输入] --> B{data值判断}
        
        B -->|data=0| C["显示MODE SELECT<br/>全位闪烁"]
        B -->|data=1| D["显示1_DISPLAY<br/>带数字前缀"]
        B -->|data=2| E["显示2_COUNTER<br/>带数字前缀"]
        B -->|data=3| F["显示3_TIMER<br/>带数字前缀"]
        B -->|data=4| G["显示4_RTIMER<br/>带数字前缀"]
        B -->|data=5| H["显示5_GUESS<br/>带数字前缀"]
        B -->|default| I["显示EEEEEEEE<br/>错误状态"]
        
        C --> J[设置star=11111111<br/>全位闪烁]
        D --> K[设置star=0<br/>静态显示]
        E --> K
        F --> K
        G --> K
        H --> K
        I --> K
        
        J --> L[seg7_starcontrol显示驱动]
        K --> L
        
        L --> M[数码管输出]
    end
    
    subgraph "显示内容编码"
        N["MODE SELECT: numstar闪烁内容"]
        O["各模式名称: num正常内容"]
        P["小数点位置: dp控制"]
    end
    
    N --> L
    O --> L
    P --> L
```
### m1_文本显示器
```mermaid
flowchart TD
    subgraph "M1_TextViewer文本显示器"
        A[外部输入] --> B[信号直接映射]
        B --> C[viewer核心模块]
        C --> D[输出接口]
        
        E["IN_SWITCH[15:0]<br/>16位开关控制"] --> B
        F["IN_BTN[4:0]<br/>5位按键输入"] --> B
        G["IN_CLK<br/>系统时钟"] --> B
        
        C --> H["数码管显示<br/>字符选择显示"]
        C --> I["LED状态指示<br/>开关状态反映"]
    end
    
    subgraph "viewer功能"
        J[开关状态解析] --> K[字符位置选择]
        K --> L[字符内容选择]
        L --> M[数码管驱动]
        
        N[按键功能] --> O[显示模式切换]
        O --> M
    end
    
    H --> P[OUT_SEG0/1_DATA]
    I --> Q[OUT_LED]
```

### m2_计数器
```mermaid
flowchart TD
    subgraph "M2_Counter计数器模块"
        A[10ms时钟分频] --> B[按键检测逻辑]
        B --> C{按键状态检测}
        
        C -->|"BTN[2]连续按下"| D[快速递增<br/>num++]
        C -->|"BTN[0]连续按下"| E[快速递减<br/>num--]
        C -->|"BTN[1]单次按下"| F[单步递增<br/>num++]
        C -->|"BTN[3]单次按下"| G[单步递减<br/>num--]
        C -->|无按键| H[保持数值]
        
        D --> I[数值范围检查<br/>0~99999999]
        E --> I
        F --> I
        G --> I
        H --> I
        
        I --> J[32位数值num]
        J --> K[LED二进制显示<br/>低16位]
        J --> L[BinToBCD_32bit转换]
        
        L --> M[BCDToSeg7_32bit转换]
        M --> N[seg7_starcontrol显示]
        N --> O[8位数码管输出]
    end
    
    subgraph "防抖机制"
        P[onTouch标志] --> Q[单次按键检测]
        Q --> R[按键释放检测]
        R --> P
    end
    
    B --> P
```

### m3_正向计时器
```mermaid
flowchart TD
    subgraph "M3_timer正向计时器"
        A[5ms时钟分频] --> B[按键检测]
        A1[1s时钟分频] --> C[时间计数逻辑]
        
        B --> D{按键检测}
        D -->|"BTN[1]"| E[复位操作<br/>pause=1, reset=1]
        D -->|"BTN[0]"| F[开始/暂停切换<br/>pause=~pause]
        
        C --> G{暂停状态?}
        G -->|运行状态| H[时间递增]
        G -->|暂停状态| I[时间停止]
        
        H --> J[毫秒计数ms++]
        H --> K[秒计数sec++]
        K --> L{进位判断}
        L -->|sec=60| M[分钟进位min++]
        M --> N{min=60?}
        N -->|是| O[小时进位hour++]
        
        J --> P[时间显示数据]
        O --> P
        
        P --> Q[BinToBCD转换<br/>4个8位转换器]
        Q --> R[BCDToSeg7转换<br/>4个转换器]
        R --> S[seg7_starcontrol]
        
        I --> T[闪烁显示逻辑<br/>暂停状态闪烁]
        T --> S
        S --> U[HH:MM:SS.ms格式显示]
    end
    
    subgraph "LED进度显示"
        V[秒数检测] --> W[LED数量控制]
        W --> X[15位LED进度条]
        Y[暂停状态] --> Z["LED[0]状态指示"]
    end
    
    K --> V
    F --> Y
```

### m4_倒计时器
```mermaid
flowchart TD
    subgraph "M4_Rtimer倒计时器"
        A[5ms时钟分频] --> B[按键检测逻辑]
        A1[100ms时钟分频] --> C[设置响应逻辑] 
        A2[1s时钟分频] --> D[倒计时逻辑]
        
        E["SW[0]开关"] --> F{复位检测}
        F -->|"SW[0]=1"| G[全部复位<br/>回到设置模式]
        F -->|"SW[0]=0"| H[正常运行]
        
        H --> I{当前状态}
        I -->|暂停状态| J[时间设置模式]
        I -->|运行状态| K[倒计时模式]
        
        J --> L[设置位选择inset]
        L --> M{按键功能}
        M -->|"BTN[0]"| N[切换设置位<br/>秒→分→时]
        M -->|"BTN[1]"| O[当前位递增]
        M -->|"BTN[3]"| P[当前位递减]
        M -->|"BTN[2]"| Q[开始/暂停]
        
        K --> R[每秒递减]
        R --> S{时间检查}
        S -->|time>0| T[正常递减<br/>借位处理]
        S -->|time=0| U[倒计时结束<br/>报警闪烁]
        
        T --> V[时间显示处理]
        U --> W[全屏闪烁ONSTOP]
        
        V --> X[BinToBCD转换组]
        W --> Y[闪烁控制]
        X --> Z[seg7_starcontrolorigin]
        Y --> Z
    end
    
    subgraph "LED进度条"
        AA[剩余秒数] --> BB[LED数量映射]
        BB --> CC["OUT_LED[15:1]进度显示"]
        DD[暂停状态] --> EE["OUT_LED[0]状态指示"]
    end
    
    subgraph "设置位闪烁"
        FF[inset状态] --> GG{设置位选择}
        GG -->|"inset[0]"| HH[秒位闪烁]
        GG -->|"inset[1]"| II[分位闪烁]
        GG -->|"inset[2]"| JJ[时位闪烁]
    end
    
    T --> AA
    Q --> DD
    L --> FF
```

### m5_猜数字
```mermaid
flowchart TD
    subgraph "M5_GuessNumber猜数字游戏"
        A[多级时钟分频] --> B[50Hz主逻辑]
        A --> C[1Hz倒计时]
        A --> D[5Hz LED流水]
        A --> E[100ms按键消抖]
        
        F[LFSR随机数生成器] --> G[16位线性反馈移位寄存器]
        G --> H[0-99范围限制]
        
        I[游戏状态机] --> J{当前状态}
        
        J -->|S_INIT| K["显示PLAY<br/>等待开始"]
        J -->|S_GEN_SECRET| L["生成随机数<br/>显示LOAD"]
        J -->|S_PROMPT_INPUT| M["输入猜测<br/>GUES XY Tt"]
        J -->|S_CHECK_GUESS| N[比较猜测结果]
        J -->|S_WIN_MSG| O["显示WIN<br/>LED流水灯"]
        J -->|S_HIGH_MSG| P["显示HIGH<br/>继续游戏"]
        J -->|S_LOW_MSG| Q["显示LOW<br/>继续游戏"]
        J -->|S_LOSE_MSG| R["显示LOSE<br/>时间耗尽"]
        
        M --> S[双位数字输入系统]
        S --> T[十位/个位切换]
        T --> U[数字递增/递减]
        U --> V[当前编辑位闪烁]
        
        N --> W{比较结果}
        W -->|相等| O
        W -->|过高| P
        W -->|过低| Q
        
        C --> X[99秒倒计时]
        X --> Y{时间检查}
        Y -->|time=0| R
        Y -->|time>0| Z[继续游戏]
        
        D --> AA[LED流水灯效果]
        AA --> BB[胜利庆祝动画]
    end
    
    subgraph "按键消抖系统"
        CC[100ms采样间隔] --> DD[边沿检测]
        DD --> EE[边沿消费机制]
        EE --> FF[防重复触发]
    end
    
    subgraph "显示系统"
        GG[字符编码库] --> HH[6位字符码]
        HH --> II[seg7_starcontrol驱动]
        II --> JJ[8位数码管显示]
        
        KK[LED控制] --> LL{游戏状态LED}
        LL -->|准备| MM["LED[0]亮起"]
        LL -->|加载| NN["LED[1]亮起"]
        LL -->|输入| OO["LED[2]亮起"]
        LL -->|检查| PP["LED[3]亮起"]
        LL -->|胜利| QQ[流水灯效果]
        LL -->|失败| RR[交替闪烁]
    end
    
    E --> CC
    B --> I
    V --> GG
    O --> AA
```