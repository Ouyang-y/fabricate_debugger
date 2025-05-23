# fabricate_debugger
A3200 fabricate_debugger

## 更新日志
### v2.8
+ 增加多pgm未加入'PROGRAM 1 STOP'判断(line 59 135 180--182 194 195)
+ 增加debugger预计时间输出(line 137 142--145)
+ 修复多pgm的主程序运动指令未在debugger中体现(line 36 37 222--228)
+ 修复error显示(line 198)
### v2.7
+ 增加“开光闸且正向x运动时报错” (line 14 22 272 291--293)
+ 增加改功率指令 (line 175--176)
### v2.6
+ 修复WAIT MOVEDONE X Y Z (line 151 -- 152)
### v2.5
+ ~~重构为function(太麻烦了)~~
+ 增加支持PROGRAM 1 RUN
  + 将多个pgm合成为temp.pgm (line 33 -- 64)
  + 生成时以'OYY_END分割pgm (line 58)
  + 分别记录加工时间 (line 211 -- 222)
  + 在分pgm时使用pgmDiv.Xsize、pgmDiv.Ysize进行分割 (line 185 -- 188)
+ 增加支持WAIT MOVEDONE X Y Z (line 150 -- 162)
### v2.4
2023-10-09
+ 加入CW/CCW纠错检测
### v2.3
2023/5/31
+ 加入CW/CCW画整个圆
### V2.2
2023/4/26
+ 加入连续.pgm加工绘制（速度colorbar仅代表当前程序，上个程序不重绘
+ 加入画图间隔
+ 改善figure1、figure2排列（现在figure2依据figure1的位置是紧贴在右侧
+ 修复0.x速度的绘图颜色
### V2.1
+ 修复CW绘制颜色
+ 修复notdwell判断
+ 修复pie图time题目文本
+ 修复LINEAR指令未运动报错
### V2.0
+ 重构
### V1.6
2022/07/19
+ 增加函数is_dwell，修复变向dwell判断
### V1.5
2022/06/21
+ 加入以'pgmVariables.mat'命名，在当前文件夹下，缓存上次运行数据
+ 改善colorbar色阶
### V1.4
2022/05/04
+ 加入变方向是否dwell判定
+ 修复CW、CCW画线
### V1.3
2021/12/1
+ 改善标识符识别逻辑
+ 加入是否画图，.pgm中的"'plotSwitch 1"即为开启画图，"'plotSwitch 0"为关闭，默认开启
+ 加入X、Y、Z轴标识
+ 改善costY变量以存储最大Y值（之前直接用最后的Y做为使用量
+ 加入进度条，可以在line 47中更改刷新间隔行数，默认为1000行
+ 加入速度颜色线，色阶为cool，若颜色变化不明显可在line 48、49中更改最大速度及最小...
速度，默认为100mm/s及0，最大速度设置过低会报错，当前速度低于最小值会画黑线
### V1.2
2021/10/20
add:
+ 增加版本更新功能，基于在matlab的搜索路径中加入函数debuggerVersionCheck()实现
+ 增加.pgm注释识别，欲在新版本debugger中实现部分绘图功能
+ 增加.pgm程序语句使用情况计数
change:
+ figure()->clf，不新建图窗
remove:
+ 移除画图首句plot3(0,0,0)，以便于平面观察非3D图
### V1.1
2021/10/05
add:
+ 增加支持标识符G92
+ 增加运行结束显示使用片长以及运行预估时间
+ 增加光闸开关线宽
+ 增加清除无关变量
+ 增加空行识别
+ 增加画图首句为plot3(0,0,0)
fixed:
+ 修正LINEAR计时为0
changed:
+ 调整标识符判断顺序
+ 调整CW/CCW中linspace取点数100->10
+ 调整figure弹出在选文件之后
+ 调整整个程序只调用两次hold