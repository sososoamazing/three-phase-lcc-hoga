function recover_failed_points
root=fileparts(fileparts(mfilename('fullpath')));setup_comparison(root);maxNumCompThreads(1);cfg=model_config();
target=fullfile(root,'05_verification','data','recovery');if ~isfolder(target),mkdir(target);end
files=dir(fullfile(root,'05_verification','data','campaign','HOGA_*.mat'));
for k=1:numel(files)
    old=load(fullfile(files(k).folder,files(k).name));
    if old.record.converged,continue;end
    output=fullfile(target,files(k).name);if isfile(output),continue;end
    op=old.op;fprintf('RECOVER Vo=%g fs=%g\n',op.Vo,op.fs);
    result=solve_hoga_accelerated(cfg,op);record=old.record;
    record.Io=result.Io_avg;record.Po=result.Po_avg;record.Irms=max(result.Ir_rms);record.Ipeak=max(result.Ir_peak);
    record.time_s=old.record.time_s+result.solve_time;record.residual=result.residual;record.converged=result.converged;
    record.validity=result.validity_flag;record.power_residual=result.power_residual;record.blocked_fraction=result.blocked_fraction;
    record.state_size=result.state_size;record.algebraic_unknowns=result.algebraic_unknowns;
    record.origin='recovery_with_original_attempt_cost_included';
    record.message='Initial rejected candidate retained in campaign/; see recovery and hoga_attempts.';
    save(output,'result','record','op','cfg','-v7');
    fprintf('RECOVERY Vo=%g fs=%g physical=%d Io=%g\n',op.Vo,op.fs,result.converged,result.Io_avg);
end
fprintf('RECOVERY_COMPLETE\n');
end
