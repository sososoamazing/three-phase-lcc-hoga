function build_fixed_vo_model(model)
% Build a separate frozen-output diagnostic, or validate an existing build.
if nargin<1,model='lcc3_comparison';end
assert(isvarname(model));root=fileparts(fileparts(mfilename('fullpath')));
% 原项目通过本机 MATLAB agentic toolkit 编辑模型；公开版不包含该私有工具路径。
% addpath(genpath('<MATLAB_AGENTIC_TOOLKIT>/simulink/tools'));
source=fullfile(fileparts(root),'MATLAB_PRJ','three_phase','hoga_simulink_accuracy_20261014','lcc3_ideal_charge.slx');
target=fullfile(root,'05_verification','models',[model '.slx']);
prefix=fullfile(root,'00_audit','data',[model '_rebuild_']);
if isfile(target)
    load_system(target);check=model_check(model,'root','["all"]','20000');
    write([prefix 'existing_check.txt'],check);
    assert(contains(string(check),'status: healthy'),'Comparison:Unhealthy','Inspect existing model.');
    assert(numel(findClamps(model))==2,'Comparison:ClampMissing','Existing file is not a completed clamp model.');
    close_system(model,0);fprintf('EXISTING_MODEL_VERIFIED\n');return
end
copyfile(source,target);load_system(target);
write([prefix 'before.txt'],model_read(model,'root','1'));
oldNames={Simulink.ID.getFullName([model ':279']),Simulink.ID.getFullName([model ':294'])};
ops={struct('op','replace_block','target','blk_279','type','ee_lib/Sources/Voltage Source','params',struct('dc_voltage','Vo_test/2')); ...
    struct('op','replace_block','target','blk_294','type','ee_lib/Sources/Voltage Source','params',struct('dc_voltage','Vo_test/2'))};
write([prefix 'replace.txt'],model_edit(model,'root',jsonencode(ops),'incremental'));
write([prefix 'after_replace.txt'],model_read(model,'root','1'));
ids=cellfun(@(x)str2double(get_param(x,'SID')),oldNames);
% Reconnect external ports lost by replacement; middle connection is preserved.
ops={struct('op','connect','target',sprintf('blk_%d.LConn1 <-> blk_303.RConn2',ids(1))); ...
    struct('op','connect','target',sprintf('blk_%d.RConn1 <-> blk_297.RConn2',ids(2)))};
write([prefix 'repair.txt'],model_edit(model,'root',jsonencode(ops),'incremental'));
ops={};caps=[289 292 293];
for k=1:3
    v=sprintf('vs%d',k);c=sprintf('conv%d',k);t=sprintf('term%d',k);
    ops{end+1}=struct('op','add_block','type','fl_lib/Electrical/Electrical Sensors/Voltage Sensor','name',sprintf('Delta_voltage_%d',k),'ref',v); %#ok<AGROW>
    ops{end+1}=struct('op','add_block','type','PS-Simulink Converter','name',sprintf('Delta_voltage_signal_%d',k),'ref',c); %#ok<AGROW>
    ops{end+1}=struct('op','add_block','type','Terminator','name',sprintf('Delta_voltage_log_%d',k),'ref',t); %#ok<AGROW>
    ops{end+1}=struct('op','connect','target',sprintf('blk_%d.LConn1 <-> #%s.LConn1',caps(k),v)); %#ok<AGROW>
    ops{end+1}=struct('op','connect','target',sprintf('blk_%d.RConn1 <-> #%s.RConn2',caps(k),v)); %#ok<AGROW>
    ops{end+1}=struct('op','connect','target',sprintf('#%s.RConn1 <-> #%s.LConn1',v,c)); %#ok<AGROW>
    ops{end+1}=struct('op','connect','target',sprintf('#%s.y1 -> #%s.u1',c,t)); %#ok<AGROW>
end
write([prefix 'sensors.txt'],model_edit(model,'root',jsonencode(ops),'incremental'));
write([prefix 'before_logging.txt'],model_read(model,'root','1'));ops={};
for k=1:3
    c=get_param(sprintf('%s/Delta_voltage_signal_%d',model,k),'SID');
    t=get_param(sprintf('%s/Delta_voltage_log_%d',model,k),'SID');
    ops{end+1}=struct('op','configure','target',sprintf('blk_%s.y1 -> blk_%s.u1',c,t), ...
        'params',struct('DataLogging','on','DataLoggingNameMode','Custom','DataLoggingName',sprintf('vDelta%d_V',k), ...
        'DataLoggingDecimateData','off','DataLoggingLimitDataPoints','off')); %#ok<AGROW>
end
write([prefix 'logging.txt'],model_edit(model,'root',jsonencode(ops),'incremental'));
write([prefix 'final_read.txt'],model_read(model,'root','1'));
check=model_check(model,'root','["all"]','20000');write([prefix 'final_check.txt'],check);
assert(contains(string(check),'status: healthy'),'Comparison:Unhealthy','Inspect connectivity diagnostics.');
assert(numel(findClamps(model))==2);
save_system(model,target);write([prefix 'clamp_sids.json'],jsonencode(ids));
close_system(model,0);fprintf('FIXED_MODEL_BUILD_COMPLETE %s\n',model);
end
function ids=findClamps(model)
blocks=find_system(model,'SearchDepth',1,'BlockType','SimscapeBlock');ids=[];
for k=1:numel(blocks)
    if strcmp(get_param(blocks{k},'ReferenceBlock'),'ee_lib/Sources/Voltage Source') && strcmp(get_param(blocks{k},'dc_voltage'),'Vo_test/2')
        ids(end+1)=str2double(get_param(blocks{k},'SID')); %#ok<AGROW>
    end
end
end
function write(file,value)
if ~ischar(value)&&~isstring(value),value=jsonencode(value);end
fid=fopen(file,'w','n','UTF-8');fprintf(fid,'%s',value);fclose(fid);
end
