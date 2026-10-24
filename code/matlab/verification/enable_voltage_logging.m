function enable_voltage_logging
root=fileparts(fileparts(mfilename('fullpath')));model='lcc3_comparison';
% 原项目通过本机 MATLAB agentic toolkit 编辑模型；公开版不包含该私有工具路径。
% addpath(genpath('<MATLAB_AGENTIC_TOOLKIT>/simulink/tools'));
target=fullfile(root,'05_verification','models',[model '.slx']);load_system(target);
audit=fullfile(root,'00_audit','data');
write(fullfile(audit,'logging_before.txt'),model_read(model,'root','1'));
ops={};
for k=1:3
    c=[470 473 476];t=[471 474 477];
    ops{end+1}=struct('op','configure','target',sprintf('blk_%d.y1 -> blk_%d.u1',c(k),t(k)), ...
        'params',struct('DataLogging','on','DataLoggingNameMode','Custom', ...
        'DataLoggingName',sprintf('vDelta%d_V',k),'DataLoggingDecimateData','off','DataLoggingLimitDataPoints','off'));
end
write(fullfile(audit,'logging_response.txt'),model_edit(model,'root',jsonencode(ops),'incremental'));
write(fullfile(audit,'logging_after.txt'),model_read(model,'root','1'));
write(fullfile(audit,'logging_check.txt'),model_check(model,'root','["all"]','20000'));
save_system(model,target);close_system(model,0);
run_simulink_comparison(false);
end
function write(file,value)
if ~ischar(value)&&~isstring(value),value=jsonencode(value);end
fid=fopen(file,'w','n','UTF-8');fprintf(fid,'%s',value);fclose(fid);
end
