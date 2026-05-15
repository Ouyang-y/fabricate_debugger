function pgm2ascript(pgmPath)

[filePath,fileName0,~]=fileparts(pgmPath);
ascriptPath = fullfile(filePath,[fileName0,'.ascript']);

rowNow=0;
[~, result] = system(sprintf('find /v /c "" "%s"', pgmPath));
rowTotal = str2double(cell2mat(regexp(result, ': (\d+)', 'tokens','once')));

fin=fopen(pgmPath,'r');
fout=fopen(ascriptPath,'w+');
fwrite(fout,'program','char');
fwrite(fout, [13, 10], 'uint8');

Timer = tic;Time = 0;
while ~feof(fin)
    rowNow = rowNow + 1;
    if toc(Timer)-Time>10
        Time = toc(Timer)
        fprintf('%.2f%%:%.1f/%.1f\n',rowNow/rowTotal,rowNow,rowTotal);
    end
    currentLine = fgetl(fin);
    if isempty(currentLine),continue;end % 空行

    s = regexpi(currentLine,'(.*?)(?=[\(\s]|$)','tokens','once');  % 标识符放入s
    if isempty(s),continue;end % 空行
    if s{1}(1)==''''
        tempLine=replace(currentLine,'''','//');
    elseif s{1}(1)=='G'
        tempLine=currentLine;
    else
        switch s{1}
            case 'LINEAR',tempLine = replace(currentLine,s{1},'G1');
            case 'RAPID',tempLine = replace(currentLine,s{1},'G0');
            case 'CW',tempLine = replace(currentLine,s{1},'G2');
            case 'CCW',tempLine = replace(currentLine,s{1},'G3');
            % case 'DWELL',tempLine = [replace(replace(currentLine,' ',''),s{1},'Dwell('),')'];
            case 'DWELL',tempLine = replace(currentLine,s{1},'G4 P');tempLine = replace(tempLine,'P ','P');
            case 'ENGLISH',tempLine = 'G70';
            case 'METRIC',tempLine = 'G71';
            case 'MINUTES',tempLine = 'G75';
            case 'SECONDS',tempLine = 'G76';
            case 'ABSOLUTE',tempLine = 'G90';
            case 'INCREMENTAL',tempLine = 'G91';
            case 'VELOCITY'
                VELOCITY = textscan(currentLine,'%s ');
                switch VELOCITY{1}{2}
                    case 'ON',tempLine = 'G108';
                    case 'OFF',tempLine = 'G109';
                    otherwise,error("Line %d:%s\ns = %s\nVELOCITY:非法操作符<%s>\n",rowNow,currentLine,s{1},VELOCITY{1}{2});
                end
            case 'ENABLE',tempLine = dealMultiAxis(currentLine,'Enable');
            case 'PSOCONTROL'
                PSO = textscan(currentLine,'%s ');
                switch PSO{1}{3}
                    case 'ON',tempLine = ['PsoOutputOn(',PSO{1}{2},')'];
                    case 'OFF',tempLine = ['PsoOutputOff(',PSO{1}{2},')'];
                    case 'RESET',tempLine = ['PsoReset(',PSO{1}{2},')'];
                    otherwise,error("Line %d:%s\ns = %s\nPSOCONTROL:非法操作符<%s>\n",rowNow,currentLine,s{1},PSO{1}{3});
                end
            case 'WAIT'
                WAIT = textscan(currentLine,'%s ');
                switch WAIT{1}{2}
                    case 'MOVEDONE',tempLine = dealMultiAxis(currentLine,'WaitForMotionDone');
                    otherwise,error("Line %d:%s\ns = %s\nWAIT:非法操作符<%s>\n",rowNow,currentLine,s{1},WAIT{1}{3});
                end
            case {'PROGRAM','PSOOUTPUT'},continue;
            case 'PT'
                PT = regexp(currentLine, '([X|Y|Z|T])(-?\d+(?:\.\d+){0,1})\s?', 'tokens');
                axis = '';axisPos = '';T=0;
                for temp = 1:length(PT)
                    switch PT{temp}{1}
                        case {'X','Y','Z'},axis = [axis,PT{temp}{1},','];axisPos = [axisPos,PT{temp}{2},','];
                        case 'T',T = PT{temp}{2};
                    end
                end
                tempLine = ['MovePt([',axis(1:end-1),'],[',axisPos(1:end-1),'],',T,')'];
            case 'CRITICAL'
                CRITICAL = textscan(currentLine,'%s ');
                switch CRITICAL{1}{2}
                    case 'START',tempLine = 'CriticalSectionStart()';
                    case 'END',tempLine = 'CriticalSectionEnd()';
                    otherwise,error("Line %d:%s\ns = %s\nPSOCONTROL:非法操作符<%s>\n",rowNow,currentLine,s{1},PSO{1}{3});
                end
            otherwise,error("Line %d:%s\ns = %s\n",rowNow,currentLine,s{1})
        end
    end
    fwrite(fout,tempLine,'char');
    fwrite(fout, [13, 10], 'uint8');
end
fwrite(fout,'end','char');
fwrite(fout, [13, 10], 'uint8');
fclose(fout);fclose(fin);
end

function tempLine = dealMultiAxis(currentLine,s)
axis = regexpi(currentLine, '.*?\s([X|Y|Z|\s]+?)\s*$', 'tokens', 'once');
tempLine = [s,'([',replace(axis{1},' ',', '),'])'];
end
