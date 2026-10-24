function run_comparison(useAccelerated)
%run_comparison Resume-safe complete campaign. Existing successful MATs are reused.
if nargin<1,useAccelerated=false;end
root=fileparts(fileparts(mfilename('fullpath')));setup_comparison(root);
cfg=model_config();maxNumCompThreads(1);startup=tic;
dataDir=fullfile(root,'05_verification','data','campaign');if ~isfolder(dataDir),mkdir(dataDir);end
% JIT warm-up is timed separately and is not a benchmark measurement.
op=struct('Vo',400,'fs',cfg.fs);edf_model(cfg,op);fha_model(cfg,op);
environment=struct('MATLAB',version,'computer',computer,'processor',getenv('PROCESSOR_IDENTIFIER'), ...
    'logical_processors',getenv('NUMBER_OF_PROCESSORS'),'numeric_threads',1,'startup_warmup_s',toc(startup), ...
    'toolboxes',ver,'configuration',cfg,'timing_scope','single numeric thread; wall-clock solver timing; cache loads excluded');
envname='environment.json';if useAccelerated,envname='environment_resume.json';end
writeJson(fullfile(dataDir,envname),environment);
points=[cfg.Vo_points(:) repmat(cfg.fs,numel(cfg.Vo_points),1)];
for Vo=cfg.typical_voltages,points=[points;repmat(Vo,numel(cfg.frequency_points),1) cfg.frequency_points(:)];end %#ok<AGROW>
points=unique(points,'rows','stable');summary=struct([]);
for k=1:size(points,1)
    op=struct('Vo',points(k,1),'fs',points(k,2));
    for name={'REFERENCE','HOGA','EDF','FHA'}
        model=name{1};tag=sprintf('%s_V%g_f%g',model,op.Vo,op.fs);
        file=fullfile(dataDir,[tag '.mat']);fprintf('POINT %s\n',tag);
        if isfile(file)
            loaded=load(file,'result','record');result=loaded.result;record=loaded.record;
            fprintf('REUSE %s\n',tag);
        else
            record=blankRecord(model,op);result=struct();
            try
                % Original H31 solves are still valid: only the evaluator was fixed.
                existing=fullfile(root,'00_audit','data','stage1_run02',sprintf('original_V%d_H31.mat',op.Vo));
                if strcmp(model,'HOGA') && op.fs==cfg.fs && isfile(existing)
                    old=load(existing,'hoga','elapsed');result=adapt_physical_result(cfg,op,old.hoga,old.elapsed,model);
                    record.origin='reused_current_audit_numeric_solve';
                elseif strcmp(model,'HOGA') && useAccelerated
                    result=solve_hoga_accelerated(cfg,op);record.origin='validated_vectorized_HOGA_continuation';
                else
                    result=solve_model(cfg,op,model);record.origin='new_numeric_solve';
                end
                record.Io=result.Io_avg;record.Po=result.Po_avg;record.Irms=max(result.Ir_rms);record.Ipeak=max(result.Ir_peak);
                record.time_s=result.solve_time;record.residual=result.residual;record.converged=result.converged;
                record.validity=result.validity_flag;record.power_residual=result.power_residual;
                record.blocked_fraction=result.blocked_fraction;record.state_size=result.state_size;
                record.algebraic_unknowns=result.algebraic_unknowns;
            catch err
                record.message=getReport(err,'extended','hyperlinks','off');fprintf('%s\n',record.message);
            end
            save(file,'result','record','op','cfg','-v7');
        end
        summary=[summary record]; %#ok<AGROW>
        writetable(struct2table(summary,AsArray=true),fullfile(dataDir,'point_summary.csv'));
        fprintf('DONE %s ok=%d Io=%.9g time=%.3g\n',tag,record.converged,record.Io,record.time_s);
    end
end
fprintf('CAMPAIGN_SOLVES_COMPLETE\n');
end
function r=blankRecord(model,op)
r=struct('model',model,'Vo',op.Vo,'fs',op.fs,'Io',NaN,'Po',NaN,'Irms',NaN,'Ipeak',NaN, ...
    'time_s',NaN,'residual',NaN,'converged',false,'validity','FAILED','power_residual',NaN, ...
    'blocked_fraction',NaN,'state_size',NaN,'algebraic_unknowns',NaN,'origin','','message','');
end
function writeJson(file,value)
fid=fopen(file,'w','n','UTF-8');fprintf(fid,'%s',jsonencode(value,PrettyPrint=true));fclose(fid);
end
