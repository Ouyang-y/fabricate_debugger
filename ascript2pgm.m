function ascript2pgm(ascriptPath)

[filePath,fileName0,~]=fileparts(ascriptPath);
pgmPath = fullfile(filePath,[fileName0,'.pgm']);

rowNow=0;
[~, result] = system(sprintf('find /v /c "" "%s"', ascriptPath));
rowTotal = str2double(cell2mat(regexp(result, ': (\d+)', 'tokens','once')));

fin=fopen(ascriptPath,'r');
fout=fopen(pgmPath,'w');

Timer = tic;Time = 0;
while ~feof(fin)
    rowNow = rowNow + 1;
    if toc(Timer)-Time>10
        Time = toc(Timer)
        fprintf('%.2f%%:\d/\d\n',rowNow/rowTotal,rowNow,rowTotal);
    end
    currentLine = fgetl(fin);
    if isempty(currentLine),continue;end % 空行

    s = regexpi(currentLine,'(.*?)(?=[\(\s]|$)','tokens','once');  % 标识符放入s
    if isempty(s),continue;end % 空行
    if s{1}(1)=='/'
        tempLine=replace(currentLine,'//','''');
    else
    switch s{1}
        case 'G1',tempLine = replace(currentLine,s{1},'LINEAR');
        case 'MoveLinear',a = regexp(currentLine,'\[(?:[X|Y|Z],?)+\]');
        case 'G0',tempLine = replace(currentLine,s{1},'RAPID');
        case 'G2',tempLine = replace(currentLine,s{1},'CW');
        case 'G3',tempLine = replace(currentLine,s{1},'CCW');
        case 'G4',tempLine = replace(currentLine,s{1},'DWELL');
        case 'G70',tempLine = 'ENGLISH';
        case 'G71',tempLine = 'METRIC';
        case 'G75',tempLine = 'MINUTES';
        case 'G76',tempLine = 'SECONDS';
        case 'G90',tempLine = 'ABSOLUTE';
        case 'G91',tempLine = 'INCREMENTAL';
        case {'G108','VelocityBlendingOn'},tempLine = 'VELOCITY ON';
        case 'G109',tempLine = replace(currentLine,s{1},'VELOCITY OFF');
        case {'Enable','Dwell'},tempLine = regexprep(regexprep(currentLine, '(\w+)\(\[?([^\]\)]+)\]?\)', '${upper($1)} ${regexprep($2,''^\s+|\s+$|,\s*'','' '')}'),'\s*',' ');
        case 'SetupTaskTimeUnits',tempLine = regexprep(currentLine, '.*TimeUnits\.(.*)\)', '${upper($1)}');
        case 'PsoReset',axis = regexp(currentLine,'\(.*(\w).*\)','tokens','once');fwrite(fout,['PSOCONTROL ',axis{1},' RESET'],'char');fwrite(fout, [13, 10], 'uint8');tempLine = ['PSOOUTPUT ',axis{1},' CONTROL 1 0'];
        case 'SetupTaskTargetMode',tempLine = regexprep(currentLine, '.*TargetMode\.(.*)\)', '${upper($1)}');
        case 'PsoOutputOff',axis = regexp(currentLine,'\(.*(\w).*\)','tokens','once');tempLine = ['PSOCONTROL ',axis{1},' OFF'];
        case 'PsoOutputOn',axis = regexp(currentLine,'\(.*(\w).*\)','tokens','once');tempLine = ['PSOCONTROL ',axis{1},' ON'];
        case 'WaitForMotionDone',axis = regexp(currentLine,'\w+\(\[?([^\]\)]+)\]?\)','tokens','once');tempLine = ['WAIT MOVEDONE ',regexprep(axis{1},'\s*,\s*',' ')];
        case {'G359','G92'},tempLine = currentLine;
        case {'program','end'},continue;
        otherwise,error("Line %d:%s\ns = %s\n",rowNow,currentLine,s{1})
    end
    end
    fwrite(fout,tempLine,'char');
    fwrite(fout, [13, 10], 'uint8');  % 直接写入 ASCII 码
end
fclose(fout);fclose(fin);
end
