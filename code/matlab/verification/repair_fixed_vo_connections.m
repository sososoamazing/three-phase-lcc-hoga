function repair_fixed_vo_connections
root=fileparts(fileparts(mfilename('fullpath')));model='lcc3_comparison';
% 原项目通过本机 MATLAB agentic toolkit 编辑模型；公开版不包含该私有工具路径。
% addpath(genpath('<MATLAB_AGENTIC_TOOLKIT>/simulink/tools'));
target=fullfile(root,'05_verification','models',[model '.slx']);load_system(target);
audit=fullfile(root,'00_audit','data');
write(fullfile(audit,'simulink_repair_before.txt'),model_read(model,'root','1'));
% These IDs and ports are from the saved before/after native model_read.
ops={struct('op','connect','target','blk_467.LConn1 <-> blk_303.RConn2'); ...
     struct('op','connect','target','blk_468.RConn1 <-> blk_297.RConn2')};
write(fullfile(audit,'simulink_repair_response.txt'),model_edit(model,'root',jsonencode(ops),'incremental'));
write(fullfile(audit,'simulink_repaired_read.txt'),model_read(model,'root','1'));
check=model_check(model,'root','["all"]','20000');
write(fullfile(audit,'simulink_repaired_check.txt'),check);
for sid=[467 468]
    block=Simulink.ID.getFullName(sprintf('%s:%d',model,sid));
    assert(strcmp(get_param(block,'dc_voltage'),'Vo_test/2'));
end
save_system(model,target);write(fullfile(audit,'clamp_source_sids.json'),'[467,468]');
close_system(model,0);fprintf('FIXED_MODEL_REPAIRED\n');
run_simulink_comparison(false);
end
function write(file,value)
if ~ischar(value)&&~isstring(value),value=jsonencode(value);end
fid=fopen(file,'w','n','UTF-8');fprintf(fid,'%s',value);fclose(fid);
end
