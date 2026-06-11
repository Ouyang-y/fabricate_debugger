%% 说明
% 该程序用于摸参数
% 功率、速度、深度
%
%% initial
clear
saveName = [pwd,filesep,mfilename,'.ascript'];
if isfile(saveName)
    if ~strcmp(questdlg([saveName,'已存在，是否覆盖？'],'文件已存在','是','否','是'),'是')
        error('不覆盖文件，请重命名');
    end
end
%% parameter
global f n y vPSOoff dt disIngroup disGroup lengthChip  %#ok
n = 1.505;  % 折射率(材料&波长 CorningEagleXG@1030nm
% n = 1.514;  % 折射率(材料&波长 CorningEagleXG@515nm
% n = 1.45;  % 折射率(材料&波长 Corning7980@1030nm
% n = 1.461536;  % 折射率(材料&波长 Corning7980@515nm
vPSOoff = 30;  % 关光闸运动速度
dt = 0.3;  % dwell标准时间
disIngroup = 15e-3;  % 组内间距
disGroup = 50e-3;  % 组间间距
lengthChip = 5+4;
y = -0.1;

dddepth = 10e-3;  % 换行深度
depth0 = -40e-3*n;
depth = (100:25:550)*1e-3+depth0;
v = [5 5 10 10 15 15 20 20 30 30];
repeatTimes = [1 3 5 7];

%% program
f=fopen(saveName,'wt');
A1s_init(f,n,depth(1),1);
nTemp = 1;move2yend = 0;All.depth=[];All.y=[];
depth=sort(depth,'descend');
for depthTemp = depth
    fprintf(f,'G1 X%f Y%f F%d\n',lengthChip,y,vPSOoff);
    fprintf(f,'WaitForMotionDone([X,Y])\n');
    for r = repeatTimes
        if(isempty(All.depth))
            All.depth = depthTemp;
            All.y = y;
        else
            Alltemp = ((All.depth-depthTemp+0.01*dddepth)>=dddepth);
            if(any(Alltemp))
                for temp = 1:length(All.depth)
                    if Alltemp(temp)
                        All.depth(temp) = depthTemp;
                        yend = y;
                        y = All.y(temp);
                        move2yend = 1;
                        break;
                    end
                end
            else
                All.depth = [All.depth,depthTemp];
                All.y = [All.y,y];
            end
        end
        fprintf(f,'G1 Z%f F1\n',-depthTemp/n);
        fprintf(f,'WaitForMotionDone([Z])\n');
        SWG(v,6,r)
        if move2yend
            move2yend=0;
            y = yend;
        end
    end
end
fprintf(f,'G1 X%f Y%f F%d\n',lengthChip,y,vPSOoff);
fprintf(f,'PsoOutputOn(X)\n');
fprintf(f,'end\n');
fclose(f);

fileName = ['/temp/',mfilename,'.ascript'];
fall = fopen([mfilename,'.py'], 'wt');
powerFileInit(fall,1);
fprintf(fall, '        setPower(ser, 36000)\n');
fprintf(fall, '        time.sleep(15)\n');
fprintf(fall, '        \n');

for powertemp = 400:-100:100
    fprintf(fall, '        # %d mW\n',powertemp);
    fprintf(fall, '        setPower(ser, 30000)\n');
    fprintf(fall, '        time.sleep(5)\n');
    fprintf(fall, '        pgmRun("%s")\n',fileName);
end
powerFileEnd(fall);


%% function
function SWG(v,numInGrop,repeat)
arguments
    v {mustBeNumeric,mustBeReal}
    numInGrop {mustBeNumeric,mustBeReal}
    repeat {mustBeNumeric,mustBeReal} = 1
end
global f vPSOoff lengthChip disGroup disIngroup y dt
for temp_j = 1:ceil(length(v)/numInGrop)
    if temp_j*numInGrop > length(v)
        vendNum = length(v);
    else
        vendNum = temp_j*numInGrop;
    end
    for temp_v = v((temp_j-1)*numInGrop+1:vendNum)
        for temp_repeat = 1:repeat
            if temp_repeat == 1,fprintf(f,"//plotSwitch 1\n");end
            fprintf(f,'G1 X%f Y%f F%d \n',lengthChip,y,vPSOoff);
            fprintf(f,'PsoOutputOn(X)\n');
            fprintf(f,'Dwell(%.1f) \n',dt);
            fprintf(f,'G1 X0 F%.2f \n',temp_v);
            fprintf(f,'WaitForMotionDone([X])\n');
            fprintf(f,'PsoOutputOff(X)\n');
            if temp_repeat == 1,fprintf(f,"//plotSwitch 0\n");end
        end
        y = y - disIngroup;
    end
    y = y - disGroup + disIngroup;
end
y = y - disGroup + disIngroup;
end

function A1s_init(f,n,depth,~)
%{
初始化并下移至加工深度(参数中不需要/n，默认Z轴速度1mm/s

输入参输：
    f:文件；
    n：折射率；
    depth：深度；
    参数4：相对/绝对运动。
输出结果：
    不输入参数4-光闸已打开，已DWELL，相对位置；
    输入参数4-光闸未知，已DWELL，绝对位置。
%}
fprintf(f,'program\n');
fprintf(f,'Enable([X,Y,Z])\n');
fprintf(f,'G71\n');	%长度单位 mm
fprintf(f,'G76\n');	%时间单位 s
fprintf(f,'G359\n');
fprintf(f,'G108\n');	%速度变化时不回到绝对0
fprintf(f,'PsoReset(X)\n');	%闸门初始化
fprintf(f,'PsoOutputConfigureOutput(X,PsoOutputPin.XR3PsoOutput2)\n');
fprintf(f,'G90\n');	%绝对位置（初始化Z轴深度
fprintf(f,"//plotSwitch 0\n"); %不对初始下降深度作图
fprintf(f,'G1 Z%f F1 \n',-depth/n);
fprintf(f,"//plotSwitch 1\n");
fprintf(f,'WaitForMotionDone(Z)\n');
if nargin < 4   % 默认不输入第4个参数
    fprintf(f,'G91\n');	%相对位置
    fprintf(f,'PsoOutputOn(X)\n');	%开关闸
else
    fprintf(f,'G92 Y0\n');	%等待0.5s
end
end

function powerFileInit(fall,~)
%{
初始化power文件

输入参输：
    fall：文件标识符；
    参数2：需要串口。
输出结果：
    不输入参数2-不开串口；
    输入参数2-开串口。
%}

fileContent = {
    'import automation1 as a1'
    'import time'
    'import sys'
    'import serial'
    'from pathlib import Path'
    ''
    'controller: a1.Controller = None'
    ''
    'def errorOccurred(error_message, ser=None):'
    '    print(f''An error occurred: {error_message}'')'
    '    try:'
    '        if ser is not None:'
    '            ser.close()'
    '    except:'
    '        pass'
    '    finally:'
    '        sys.exit(1)'
    ''
    'def setPower(ser, power):'
    '    strtemp = ''Y={}/''.format(power)'
    '    print(strtemp)'
    '    ser.write(strtemp.encode(''utf-8''))'
    '    '
    'def pgmRun(aeroscript_program_path):'
    '    if not controller:'
    '        print(''You must connect to the controller before moving an axis'')'
    '        return'
    '    controller.files.upload(Path(aeroscript_program_path).name, aeroscript_program_path)'
    '    controller.runtime.tasks[1].program.run(aeroscript_program_path)'
    '    controller_task_status = controller.runtime.tasks[1].status'
    '    temp = Path(aeroscript_program_path).stem'
    '    print()'
    '    while(controller_task_status.task_state!=a1.TaskState.ProgramComplete):'
    '        if controller_task_status.task_state == a1.TaskState.Error:'
    '            print(f''An AeroScript error occurred: {controller_task_status.error_message}'')'
    '        elif controller_task_status.task_state == a1.TaskState.Idle:'
    '            print(''No AeroScript program is loaded or running'')'
    '        elif controller_task_status.task_state == a1.TaskState.ProgramReady:'
    '            print(''The AeroScript program has not started yet'')'
    '        elif controller_task_status.task_state == a1.TaskState.ProgramRunning:'
    '            print(''\033[F\033[K{} | {} is running''.format(time.strftime("%Y-%m-%d %H:%M:%S",time.localtime(time.time())),temp,end="",flush=True))'
    '        elif controller_task_status.task_state == a1.TaskState.ProgramPaused:'
    '            print(''The AeroScript program is paused'')'
    '        time.sleep(5)'
    '        controller_task_status = controller.runtime.tasks[1].status'
    ''
    'def main():'
    '    global controller'
    '    try:'
    '        controller = a1.Controller.connect()'
    '        controller.start()'
    '    except:'
    '        errorOccurred(''connecting/starting controller'')'
    '    '
    '    ser = None'
};
for i = 1:length(fileContent)
    fprintf(fall, '%s\n', fileContent{i});
end
if nargin < 2
    fprintf(fall, '    # try:\n');
    fprintf(fall, '    #     ser = serial.Serial(port=''COM2'', baudrate=9600, parity=None, bytesize=8,stopbits=1, timeout=None)\n');
    fprintf(fall, '    # except:\n');
    fprintf(fall, '    #     errorOccurred(''connecting to serial port'', ser)\n');
else
    fprintf(fall, '    try:\n');
    fprintf(fall, '        ser = serial.Serial(port=''COM1'')\n');
    fprintf(fall, '    except:\n');
    fprintf(fall, '        errorOccurred(''connecting to serial port'', ser)\n');
end
fprintf(fall, '\n');
fprintf(fall, '    try:\n');
end

function powerFileEnd(fall)
fileContent = {
    ''
    '    except a1.ControllerException as controller_exception:'
    '        print(f''Unexpected {type(controller_exception).__name__} ({controller_exception.error}): {controller_exception.message}'')'
    '        errorOccurred(''running the program'', ser=ser)'
    ''
    'if __name__ == "__main__":'
    '    main()'
    ''
};
for i = 1:length(fileContent)
    fprintf(fall, '%s\n', fileContent{i});
end
fclose(fall);
end
