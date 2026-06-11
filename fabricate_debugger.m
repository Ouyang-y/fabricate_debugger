%% 选取.ascript文件
% dbclear if error
% dbstop if error
[fileName,filePath]=uigetfile({'*.ascript;*.py','fabricate files';'*.*','All Files'});
ascriptPath = fullfile(filePath,fileName);

ticAll = tic;
if ~fileName,error('未选取文件');end
suffix = regexp(fileName, '\.([^.]+)$', 'tokens', 'once');
if isempty(suffix),error('选取文件无“.”');end
if ~any(strcmp(suffix,{'ascript','py'})),error('未选取.ascript或.py文件');end

%% 预设参数
global Velocity_min Velocity_max dtime WarnX plotSwitchMain  %#ok
rowPeriod = 30000;  % 进度条间隔，越大运行越快；减小可以观察画线
Velocity_max_input = [];  % 若开光闸运行速度在最大与最小之外，线为黑色
Velocity_min_input = [];  % 设为[]则自动遍历开光闸速度
dtime = 0;  % 画图间隔
continue_fabricata = 0;  % 设为1则启动连续加工模式,绘图colorbar仅依据当前程序
pgmDiv.Xsize = 5;
pgmDiv.Zsize = 0.05;
WarnX = 1;  % 开光闸且x正向运动时报错
plotSwitchMain = 1;

%% 保存提供加工程序的工作区
if ~continue_fabricata
    save('temp.mat',"Velocity_min_input","Velocity_max_input","Velocity_min","Velocity_max","dtime","rowPeriod","continue_fabricata","ascriptPath","pgmDiv","ticAll","filePath","suffix","plotSwitchMain")
    clearvars Velocity_min_input Velocity_max_input dtime rowPeriod continue_fabricata
    save('pgmVariables.mat')
    clear
    load("temp.mat")
    delete("temp.mat")
end

%% PROGRAM构建新文件为temp.ascript
ascript.list = {};
ascript.num = 0;
timepy = [];
if strcmp(suffix,'py')
    pwd0 = pwd;
    cd(filePath);
    tic,f=fopen(ascriptPath,'r');
    while ~feof(f)
        currentLine = fgetl(f);
        if isempty(currentLine),continue;end  % 空行
        s = regexp(currentLine,' *time\.sleep\((\d+)\)','tokens','once');
        if ~isempty(s),timepy = [timepy,str2double(s{1})];continue;end  %#ok
        s = regexp(currentLine,' *pgmRun\("([^"]*)"\)','tokens','once');
        if isempty(s),continue;end  % 空行
        ascript.num = ascript.num+1;
        [~,temp] = fileparts(s{1});
        ascript.list(ascript.num)={[temp,'.ascript']};
    end
    fclose(f);toc,fprintf('检测pgmRun完成\n');
end

if ascript.num
    tic,fprintf('检测到pgmRun,合并存储为temp.ascript\n');
    f=fopen('temp.ascript','w');
    for temp = 1:ascript.num
        ftemp = fopen(ascript.list{temp},'r');
        while ~feof(ftemp)
            currentLine = fgets(ftemp);
            fwrite(f,currentLine);
        end
        fwrite(f,sprintf('\n//OYY_END\n'));
        fclose(ftemp);
    end
    fclose(f);toc,fprintf('temp.ascript生成完成\n');
    ascriptPath = 'temp.ascript';
end

%% 计算文本总行数
tic,f=fopen(ascriptPath,'r');
rowTotal = 0;
while ~feof(f)
    rowTotal = rowTotal + sum(fread(f,10000,'char')==10);
end
fclose(f);toc
fprintf('.ascript总行数%d\n',rowTotal);

%% 找出速度最大值、最小值
vmax=0;vmin=0;isPlot=1;isPSOOn=1;
if isempty(Velocity_max_input),vmax=1;Velocity_max = -inf;end
if isempty(Velocity_min_input),vmin=1;Velocity_min = inf;end
if vmax||vmin
    tic,f=fopen(ascriptPath,'r');
    while ~feof(f)
        currentLine = fgetl(f);
        if isempty(currentLine),continue;end  % 空行
        currentLine = currentLine(~isspace(currentLine));
        if isPSOOn && isPlot && currentLine(1) == 'G' && any(sscanf(currentLine(2:end),'%d',1)==[0,1,2,3])
            Velocity_temp = sscanf(currentLine,'%*[^F]F%f');
            if vmax,Velocity_max = max(Velocity_temp,Velocity_max);end
            if vmin,Velocity_min = min(Velocity_temp,Velocity_min);end
            continue;
        end
        if strncmp(currentLine,'PsoOutputConfigureOutput',24),isPSOOn = 0;continue;end
        if strncmp(currentLine,'PsoOutputOff',12),isPSOOn = 0;continue;end
        if strncmp(currentLine,'PsoOutputOn',11),isPSOOn = 1;continue;end
        if strncmp(currentLine,'PsoWaveformOn',13),isPSOOn = 1;continue;end
        if strncmp(currentLine,'//plotSwitch',12),isPlot = str2double(currentLine(end));continue;end
    end,toc
    temp = ceil(log10(Velocity_max))+6;
    fprintf('最大速度：%*.4f\n最小速度：%*.4f\n',temp,Velocity_max,temp,Velocity_min);
end
toc(ticAll)

%% main
f=fopen(ascriptPath,'r');
Category = {'LINEAR';'CW&CCW';'DWELL';'PT'};Time = zeros(length(Category),1);
time = table(Category,Time);time.Properties.VariableUnits = {'' 's'};
timeList = zeros(ascript.num,1);Category = {'LINEAR';'DWELL';'PSOCONTROL';'CW&CCW';'INCREMENTAL&ABSOLUTE';'PT';'Other'};
Count = zeros(length(Category),1);count = table(Category,Count);

rowNow = 0;  % 当前行数

if plotSwitchMain
    f1=figure(1);hold on;%daspect([1 1 1])
end

if ~exist("PointNow","var")
    if plotSwitchMain
        f1=figure(1);hold on;%daspect([1 1 1])
        clf;hold on;
        xlabel('X','Color','r');ylabel('Y','Color','r');zlabel('Z','Color','r');
        view([1,5,3]);
    end
    global PointBefor PointNow PointG92 isABSOLUTE costY...	% 位置状态
        VelocityBefor VelocityNow Vindex notdwell ...       % 运动状态
        plotSwitch pgmF pgmR pgmT lineColorF lineWidth lineColor  %#ok 绘图参数
    PointBefor=[0,0,0];PointNow=[0,0,0];PointG92=[0,0,0];costY=0;
    VelocityBefor=[0,0,0];VelocityNow=[0,0,0];Vindex = 1;
    plotSwitch=1;pgmF=nan;pgmR=[];lineWidth=0.1;lineColor=[1 1 1];pgmT=[];
end
if Velocity_min<1,Vindex = 1/Velocity_min;end
Velocity_min=Vindex*Velocity_min-1;Velocity_max=Vindex*Velocity_max;
lineColorF = colormap(cool(fix(Velocity_max - Velocity_min)));
notdwell=[0,0,0];PgmStopCheck = 1;pgmCount = 1;
% waitBar=waitbar(0,'1','name','SIMULATING...');
ticPlot = tic;

while ~feof(f)
    rowNow = rowNow + 1;
    if mod(rowNow,rowPeriod) == 0
        costNow = toc(ticPlot);
        costAll = costNow/rowNow*(rowTotal-rowNow);
        fprintf("已用时：%12.3f 秒，剩余预计：%12.3f 秒\n",costNow,costAll);
        % waitBar=waitbar(rowNow/rowTotal,waitBar,sprintf('%.3g%%，rowNow=%d\nrowTotal=%d\n已用时：%12.3f 秒，剩余预计：%12.3f 秒',...
        %     rowNow/rowTotal*100,rowNow,rowTotal,costNow,costAll));
    end
    currentLine = fgetl(f);
    if isempty(currentLine),continue;end  % 空行
    currentLine = currentLine(~isspace(currentLine));  % 除空格

    if currentLine(1) == 'G'
        s = regexp(currentLine, '[XYZEFGIJKR][^XYZEFGIJKR]*', 'match');
        switch sscanf(currentLine(2:end),'%d',1)
            case 1,time.Time(1)=time.Time(1)+LINEAR(s(2:end));count.Count(1)=count.Count(1)+1;  % LINEAR
            case 2,time.Time(2)=time.Time(2)+CW(0,s(2:end));count.Count(4)=count.Count(4)+1;  % CW
            case 3,time.Time(2)=time.Time(2)+CW(1,s(2:end));count.Count(4)=count.Count(4)+1;  % CCW
            case 4,time.Time(3)=time.Time(3)+str2double(currentLine(4:end));count.Count(2)=count.Count(2)+1;notdwell=[0,0,0];VelocityNow=[0,0,0];  % DWELL
            case 90,isABSOLUTE=1;count.Count(5)=count.Count(5)+1;  % ABSOLUTE
            case 91,isABSOLUTE=0;count.Count(5)=count.Count(5)+1;  % INCREMENTAL
            case 92,G92(s{2:end});count.Count(end)=count.Count(end)+1;
            case {71,76,108,359},count.Count(end)=count.Count(end)+1;
            otherwise,error("G-Code非识别操作符：%s\n",s{1});
        end
    else
        if strncmp(currentLine,'MoveLinear',5),s = a1_XYZFget(currentLine(12:end-1));time.Time(1)=time.Time(1)+LINEAR(s(2:end));count.Count(1)=count.Count(1)+1;continue;end
        if strncmp(currentLine,'Dwell',5),time.Time(3)=time.Time(3)+str2double(currentLine(7:end-1));count.Count(2)=count.Count(2)+1;notdwell=[0,0,0];VelocityNow=[0,0,0];continue;end
        if strncmp(currentLine,'WaitForMotionDone',8)
            time.Time(3)=time.Time(3)+0.1;count.Count(2)=count.Count(2)+1;
            if any(currentLine == 'X'), notdwell(1)=0; VelocityNow(1)=0; end
            if any(currentLine == 'Y'), notdwell(2)=0; VelocityNow(2)=0; end
            if any(currentLine == 'Z'), notdwell(3)=0; VelocityNow(3)=0; end
            continue;
        end
        if strncmp(currentLine,'PsoOutputOff',11),lineColor = [1 1 0];lineWidth = 0.1;count.Count(end)=count.Count(end)+1;continue;end
        if strncmp(currentLine,'PsoOutputOn',11)||strncmp(currentLine,'PsoWaveformOn',13),lineColor = [0 0 0];lineWidth = 1.5;count.Count(end)=count.Count(end)+1;continue;end
        if strncmp(currentLine,'PsoReset',8),lineColor = [1 1 0];lineWidth = 0.1;count.Count(end)=count.Count(end)+1;continue;end
        if strncmp(currentLine,'VelocityBlendingOn',18),count.Count(end)=count.Count(end)+1;continue;end
        if strncmp(currentLine,'SetupTaskTimeUnits',18),count.Count(end)=count.Count(end)+1;continue;end
        if strncmp(currentLine,'MoveCw',6),s = a1_XYZFRget(currentLine(8:end-1));time.Time(2)=time.Time(2)+CW(0,s{1}(2:end));count.Count(4)=count.Count(4)+1;continue;end
        if strncmp(currentLine,'MoveCcw',6),s = a1_XYZFRget(currentLine(9:end-1));time.Time(2)=time.Time(2)+CW(1,s{1}(2:end));count.Count(4)=count.Count(4)+1;continue;end
        if strncmp(currentLine,'MovePt',5),s = a1_XYZFget(currentLine(8:end-1));time.Time(4)=time.Time(4)+LINEAR(s(2:end));count.Count(6)=count.Count(6)+1;continue;end
        if strncmp(currentLine,'SetupTaskTargetMode',19)
            if length(currentLine)<32,error("SetupTaskTargetMode非识别操作符：%s\n",currentLine);end
            if currentLine(32) == 'I',isABSOLUTE=0;count.Count(5)=count.Count(5)+1;
            elseif currentLine(32) == 'A',isABSOLUTE=1;count.Count(5)=count.Count(5)+1;
            else,error("SetupTaskTargetMode非识别操作符：%s\n",currentLine);
            end
            continue;
        end
        if strncmp(currentLine,'PositionOffsetSet',17),s = a1_XYZFget(currentLine(19:end-1));G92(s{2:end});count.Count(end)=count.Count(end)+1;continue;end
        if strcmp(currentLine,'end'),PgmStopCheck = 0;count.Count(end)=count.Count(end)+1;continue;end
        if strncmp(currentLine,'PsoOutputConfigureOutput',10),count.Count(end)=count.Count(end)+1;continue;end
        if strncmp(currentLine,'PsoWaveformOn',13),count.Count(end)=count.Count(end)+1;continue;end
        if currentLine(1) == '/'  % 注释行
            if strncmp(currentLine,"//plotSwitch",12),plotSwitch = str2double(currentLine(end));continue;end
            if strcmp(ascriptPath,'temp.ascript') && strcmp(currentLine,"//OYY_END")  % .ascript之一终止
                mesh([0,0;pgmDiv.Xsize,pgmDiv.Xsize],[costY,costY;costY,costY],[PointNow(3),PointNow(3)-pgmDiv.Zsize;PointNow(3),PointNow(3)-pgmDiv.Zsize],EdgeColor='k',LineWidth=2,FaceColor='w',FaceAlpha=0.3);
                if PgmStopCheck,error("请检查'%s'中是否含有end\n",ascript.list{pgmCount});else,PgmStopCheck=1;end
                timeList(pgmCount) = sum(time.Time);pgmCount = pgmCount+1;notdwell=[0,0,0];continue;
            end
        end
        if strcmp(currentLine(1:3),'var'),count.Count(end)=count.Count(end)+1;continue;end  % 变量行
        if strcmp(currentLine,'program'),count.Count(end)=count.Count(end)+1;continue;end
        if strncmp(currentLine,'Enable',6),count.Count(end)=count.Count(end)+1;continue;end
        if strncmp(currentLine,'DriveArrayWrite',15),count.Count(end)=count.Count(end)+1;continue;end
        if strncmp(currentLine,'PsoDis',6),count.Count(end)=count.Count(end)+1;continue;end
        if strncmp(currentLine,'PsoWaveformConfigureMode',24),count.Count(end)=count.Count(end)+1;continue;end
        
        warning("未能识别标识符(Line %d)：%s\n", rowNow, currentLine);
    end
end

%% close
fclose("all");
% delete(waitBar);
hold off;
numV = fix(Velocity_max - Velocity_min);
Velocity_min = Velocity_min + 1;
if numV > 10,c = colorbar('Ticks',0:0.1:1,'TickLabels',{linspace(Velocity_min,Velocity_max,11)/Vindex});
else,c = colorbar('Ticks',linspace(0,1,numV),'TickLabels',{linspace(Velocity_min,Velocity_max,numV)/Vindex});
end,c.Label.String = '开光闸的运动速度';
% msgbox
msg = {['片长(Y)总消耗：',num2str(costY),'mm']};
time_all = sum(time.Time) + sum(timepy);
hour = floor(time_all / 3600);minute = floor((time_all - hour*3600) / 60);second = floor(time_all - hour*3600 - minute*60);
msgTime = '预计加工时间：';
if hour,msgTime = [msgTime,num2str(hour),'h'];end
if minute,msgTime = [msgTime,num2str(minute),'m'];end
if second,msgTime = [msgTime,num2str(second),'s'];end
msg(2,1) = {msgTime};
if ascript.num
    delete('temp.ascript');
    timeListtemp = [timeList(1);diff(timeList)];
    for temp = 1:ascript.num
        timetemp = timeListtemp(temp);
        hour = floor(timetemp / 3600);minute = floor((timetemp - hour*3600) / 60);second = floor(timetemp - hour*3600 - minute*60);
        msgTime = [msgTime,newline,ascript.list{temp},':'];%#ok
        if hour,msgTime = [msgTime,num2str(hour),'h'];end%#ok
        if minute,msgTime = [msgTime,num2str(minute),'m'];end%#ok
        if second,msgTime = [msgTime,num2str(second),'s'];end%#ok
    end
end
if strcmp(suffix,'py'),cd(pwd0);end
% plot summary pie
f2 = figure(2);f2.Position = [f1.Position(1)+f1.Position(3),f1.Position(2:4)];
subplot(1,2,1);pie(count.Count,count.Category);title('Count','Color','red');
subplot(1,2,2);pie(time.Time,time.Category);title('Time','Color','red');
disp(count),disp(msgTime),disp(time),disp(msg)
fabricate_debugger_costY = msg{1};fabricate_debugger_costTime = msg{2};
if ~continue_fabricata
    clearvars -except fabricate_debugger_costY fabricate_debugger_costTime time count costY f1;f1=figure(1);
    load('pgmVariables.mat');delete('pgmVariables.mat');
end

%% function
function SWITCH(s)
global PointNow PointG92 isABSOLUTE pgmF pgmI pgmJ pgmR pgmT Vindex  %#ok
temp = str2double(s(2:end));
switch s(1)
    case 'X'
        if isABSOLUTE,PointNow(1)=temp+PointG92(1);
        else,PointNow(1)=temp+PointNow(1);
        end
    case 'Y'
        if isABSOLUTE,PointNow(2)=temp+PointG92(2);
        else,PointNow(2)=temp+PointNow(2);
        end
    case 'Z'
        if isABSOLUTE,PointNow(3)=temp+PointG92(3);
        else,PointNow(3)=temp+PointNow(3);
        end
    case 'F',pgmF=temp*Vindex;
    case 'I',pgmI=temp;
    case 'J',pgmJ=temp;
    case 'R',pgmR=temp;
    case 'T',pgmF=nan;pgmT=temp;
    otherwise,error('SWITCH:未能识别%s',s(1));
end
end

function G92(varargin)
global PointG92 PointNow    %#ok
for temp = varargin
    switch temp{1}(1)
        case 'X',PointG92(1)=PointNow(1) - str2double(temp{1}(2:end));
        case 'Y',PointG92(2)=PointNow(2) - str2double(temp{1}(2:end));
        case 'Z',PointG92(3)=PointNow(3) - str2double(temp{1}(2:end));
        otherwise,error([mfilename,'：操作符非法'],'G92:非法操作符');
    end
end
end

function time = LINEAR(s)
global PointBefor PointNow costY WarnX...	% 位置状态
    VelocityBefor VelocityNow Velocity_min Velocity_max Vindex notdwell ...	% 运动状态
    plotSwitchMain plotSwitch pgmF pgmT lineColorF lineWidth lineColor dtime    %#ok    % 绘图参数
PointBefor = PointNow;VelocityBefor = VelocityNow;  % 保存前一状态
for temp=s,SWITCH(temp{:});end
if PointNow(2)<costY;costY=PointNow(2);end
VelocityNow=PointNow-PointBefor;
if ~any(VelocityNow);time=0;return;end  % 若不动，直接返回
L=norm(VelocityNow);    % 移动距离
VelocityNow=VelocityNow/norm(VelocityNow);
%
if isnan(pgmF),pgmF=L/pgmT;end
% 判断前一状态与现在状态是否符合物理逻辑关系
notdwell = is_dwell(VelocityBefor,VelocityNow,notdwell);
% 画图
if plotSwitchMain && plotSwitch
    if dtime,pause(dtime);end
    temp = plot3([PointBefor(1),PointNow(1)],[PointBefor(2),PointNow(2)],...
        [PointBefor(3),PointNow(3)],'.-','LineWidth',lineWidth);
    if ~any(lineColor)&&pgmF>=Velocity_min&&pgmF<=Velocity_max
        temp.Color = lineColorF(max(1,floor(pgmF - Velocity_min)),:);
        if WarnX&&VelocityNow(1)>0
            error('开光闸时正向运动，请检查程序')
        end
    else,temp.Color = lineColor;
    end
end
time = L/pgmF*Vindex;
end

function time = CW(isCCW,s)
global PointBefor PointNow pgmI pgmJ pgmR costY...	% 位置状态
    VelocityBefor VelocityNow Velocity_min Velocity_max Vindex notdwell ...	% 运动状态
    plotSwitchMain plotSwitch pgmF lineColorF lineWidth lineColor dtime    %#ok    % 绘图参数
curveNum = 9;  % curveNum-1段直线描述一段弧
PointBefor = PointNow;VelocityBefor = VelocityNow;  % 保存前一状态
for temp = s,SWITCH(temp{:});end
PB2PE = PointNow - PointBefor;
Vertical = cross(VelocityBefor,PB2PE);
Vertical = Vertical/norm(Vertical);
if isempty(pgmR)
    % 输入为IJ，I对应指定终点第一个轴起始坐标的相对偏移量
    O = PointBefor;
    notdwell = zeros(1,3);
    switch s{1}(1)
        case 'X',O(1) = O(1)+pgmI;notdwell(1)=1;
        case 'Y',O(2) = O(2)+pgmI;notdwell(2)=1;
        case 'Z',O(3) = O(3)+pgmI;notdwell(3)=1;
    end
    switch s{2}(1)
        case 'X',O(1) = O(1)+pgmJ;notdwell(1)=1;
        case 'Y',O(2) = O(2)+pgmJ;notdwell(2)=1;
        case 'Z',O(3) = O(3)+pgmJ;notdwell(3)=1;
    end
    if ~any(VelocityBefor)
        Vertical = cross(PB2PE,O-PointBefor);
        Vertical = Vertical/norm(Vertical);
    end
    % 半径为起始位置与指定偏移量之间的距离
    pgmR = norm(O - PointBefor);
else    % 输入为R
    notdwell = zeros(1,3);
    % 运动轴置为未dwell
    switch s{1}(1)
        case 'X',notdwell(1)=1;
        case 'Y',notdwell(2)=1;
        case 'Z',notdwell(3)=1;
    end
    switch s{2}(1)
        case 'X',notdwell(1)=1;
        case 'Y',notdwell(2)=1;
        case 'Z',notdwell(3)=1;
    end
    Fr1 = cross(VelocityBefor,Vertical);	% 起点-R*向量Fr1为圆心
    O=PointBefor-pgmR*Fr1;
end
if PB2PE == 0
    theta = 2*pi;
    pgmR = sqrt(pgmI^2+pgmJ^2);
else
    n1=(PointBefor-O)/pgmR;n2=cross(Vertical,n1); %参数方程径向向量
    O2PE=PointNow - O;O2PB=PointBefor - O;
    theta=atan2(dot(O2PE,n2),dot(O2PE,n1));
    T = [n1',n2',O']; % 坐标系变换矩阵
    if isCCW,theta=-theta;end
    if dot(cross(O2PB,O2PE),[0,0,1])>0,theta=2*pi-theta;end  % 旋转轴与z轴点积，正负影响CW/CCW
    VelocityNow = (T*[-sin(theta);cos(theta);0])';
end
if isCCW,t = linspace(theta,2*pi,curveNum);else,t = linspace(0,theta,curveNum);end
% 画图
if plotSwitchMain && plotSwitch
    if dtime,pause(dtime);end
    if PB2PE == 0
        Axis = 'XYZ';Axis(strfind(Axis,s{1}(1)))=[];Axis(strfind(Axis,s{2}(1)))=[];
        switch(Axis)
            case 'X',Move.X = ones(1,curveNum)*O(1);
            case 'Y',Move.Y = ones(1,curveNum)*O(2);
            case 'Z',Move.Z = ones(1,curveNum)*O(3);
            otherwise,error('error');
        end
        switch(s{1}(1))
            case 'X',Move.(s{1}(1))=pgmR*cos(t)+O(1);
            case 'Y',Move.(s{1}(1))=pgmR*cos(t)+O(2);
            case 'Z',Move.(s{1}(1))=pgmR*cos(t)+O(3);
        end
        switch(s{2}(1))
            case 'X',Move.(s{2}(1))=pgmR*sin(t)+O(1);
            case 'Y',Move.(s{2}(1))=pgmR*sin(t)+O(2);
            case 'Z',Move.(s{2}(1))=pgmR*sin(t)+O(3);
        end
    else
        A = [pgmR*cos(t);pgmR*sin(t);ones(1,curveNum)];	% 圆平面坐标系的参数方程[x,y,1]
        B = T*A;    % 局部坐标系{X'OY'}转换到{XYZ}
        Move.X = B(1,:);Move.Y = B(2,:);Move.Z = B(3,:);
    end
    if any(Move.Y<costY);costY=min(Move.Y(Move.Y<costY));end   % 判断Y消耗长度
    temp = plot3(Move.X,Move.Y,Move.Z,'-','LineWidth',lineWidth,'Color',lineColor);
    temp2 = plot3([Move.X(1) Move.X(end)],[Move.Y(1) Move.Y(end)],[Move.Z(1) Move.Z(end)],'.'); % 首尾两点标记
    if ~any(lineColor)&&pgmF>=Velocity_min&&pgmF<=Velocity_max
        temp.Color = lineColorF(max(1,floor(pgmF - Velocity_min)),:);
    else,temp.Color = lineColor;
    end,temp2.Color = temp.Color;
end
time = abs(t(1)-t(end))*pgmR/pgmF*Vindex;
pgmR=[];pgmI=[];pgmJ=[];
end

function notdwell = is_dwell(v0,v1,notdwell)
%{
判断3轴大幅度变相前是否dwell

输入参输：
v0：前一状态末速度
v1：现状态初速度
notdwell：三轴dwell情况，1--未dwell
输出结果：
若大幅变相未dwell，报错轴、行数、行内容
无误则更新notdwell
%}
ismove = ones(1,3);
ismove(v1==0) = v1(v1==0);  % 认为现状态初速度为0的轴为未运动轴
if any(notdwell&ismove)	% 运动轴未dwell
    if dot(v0,v1) < 0.98 % 夹角大于8.11°
        % 可以报错了
        global currentLine rowNow %#ok
        temp = {'x','y','z'};temp = temp(notdwell==1);temp = [temp{:}];
        error(['变向',temp,'未DWELL：%s，line %d，请尝试',...
            '调大程序的判断条件0.1，或直接备注掉is_dwell函数'],currentLine,rowNow)
    end
end
notdwell = ismove;
end

function res3 = a1_XYZFget(s)
%{
% 测试用例
test1 = '[X,Y,Z],[20,-1,-4],50';
test2 = '[X,Y],[-5,-10.224],1.56';
test3 = '[X,Y],[-5,-10.224]';
test4 = '[X],[-5]';
test5 = 'X,-20.111';

% 执行转换
r1 = a1_XYZFget(test1);  % {'X20', 'Y-1', 'Z-4', 'F50'}
r2 = a1_XYZFget(test2);  % {'X-5', 'Y-10.224', 'F1.56'}
r3 = a1_XYZFget(test3);  % {'X-5', 'Y-10.224'}
r4 = a1_XYZFget(test4);  % {'X-5'}
r5 = a1_XYZFget(test5);  % {'X-20.111'}
%}
res = regexp(s, '\[?([XYZ]),?([XYZ])?,?([XYZ])?\]?,\[?(-?\d*\.?\d*),?(-?\d*\.?\d*),?(-?\d*\.?\d*)\]?,?(-?\d*\.?\d*)', 'tokens', 'once');
res1 = res(~cellfun('isempty', res));  % 移除空元素
res2 = res1;
l = length(res1);
if bitget(l,1)
    l = l - 1;  % 如果长度为奇数，去掉最后一个元素
    for temp = 1:l/2
        res2{temp} = [res2{temp}, res2{temp+l/2}];
    end
    temp = temp + 1;
    res2{temp} = ['F',res2{end}];
else
    for temp = 1:l/2
        res2{temp} = [res2{temp}, res2{temp+l/2}];
    end
end
res3 = res2(1:temp);  % 删除后半部分元素
end

function res2 = a1_XYZFRget(s)
%{
% 测试用例
test1 = '[X,Y],[20,-1],50';
test2 = '[X,Y],[20,-1],50,40';
test3 = '[X,Y],[-5,-10.224],[20,-1],1.56';
test4 = '[X,Y],[-5,-10.224],[20,-1]';

% 执行转换
r1 = a1_XYZFRget(test1);  % {'X20', 'Y-1', 'R50'}
r2 = a1_XYZFRget(test2);  % {'X20', 'Y-1', 'R50', 'F40'}
r3 = a1_XYZFRget(test3);  % {'X-5', 'Y-10.224','I20', 'J-1', 'F1.56'}
r4 = a1_XYZFRget(test4);  % {'X-5', 'Y-10.224', 'I20', 'J-1'}
%}
res = regexp(s, '\[([XYZ]),([XYZ])\],\[(-?\d*\.?\d*),(-?\d*\.?\d*)\],\[?(-?\d*\.?\d*),?(-?\d*\.?\d*)\]?,?(-?\d*\.?\d*)?', 'tokens', 'once');
res1 = res(~cellfun('isempty', res));  % 移除空元素

if count(res1,'[')>2
    % IK method
    res2 = {[res1{1}, res1{3}], [res1{2}, res1{4}], ['I', res1{5}], ['J', res1{6}]};
    isF = length(res1) == 7;
else
    % R method
    res2 = {[res1{1}, res1{3}], [res1{2}, res1{4}], ['R', res1{5}]};
    isF = length(res1) == 6;
end
if isF
    res2 = {res2,['F', res1{end}]};
end
end
