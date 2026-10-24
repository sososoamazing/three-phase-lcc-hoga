function result=adapt_physical_result(cfg,op,raw,elapsed,model)
%adapt_physical_result Common SI measurements; preserve raw solver evidence.
tau=(0:cfg.samples-1)'/cfg.samples;
if strcmp(model,'HOGA')
    raw=lcc3v2FinalizeOpen(raw);
    [x,j]=lcc3v2Evaluate(raw,tau);g=lcc3v2Geometry();
    waveform=struct('tau',tau,'i_A',x(:,1:2)*g.U','vDelta_V',x(:,5:6)*g.U'/cfg.n_sp, ...
        'jSecondary_A',j*g.U','iRect_A',sum(max(j*g.U',0),2));
    if isfield(raw.solver_history,'event_residual_scaled')
        residual=raw.solver_history.event_residual_scaled;
    else
        residual=min([raw.solver_history.spectral_normal_residual_V])/max(1,op.Vo+2*cfg.Vf_rect);
    end
    peak=fourier_current_peaks(raw);converged=raw.converged_algebraic && raw.physical_guard_pass;
    unknowns=numel(raw.event_schedule.edges);
    stateSize=4*raw.H+unknowns; % real current coefficients + DC/event coordinates
else
    waveform=struct('tau',tau);names={'i_A','vDelta_V','jSecondary_A','iRect_A'};
    t=raw.t_over_T;
    for k=1:numel(names)
        values=raw.wave.(names{k});
        waveform.(names{k})=interp1([t(end)-1;t;t(1)+1],[values(end,:);values;values(1,:)],tau,'linear');
    end
    residual=raw.closure_scaled;peak=raw.metric.iLine_peak_A;
    converged=raw.converged_periodic && raw.physical_guard_pass;stateSize=6;unknowns=6;
end
flag='CCM';if raw.metric.all_blocked_fraction>1e-5,flag='OUTSIDE_TARGET_CCM';end
if ~converged,flag=['INVALID_' raw.status];end
result=struct('model',model,'Io_avg',raw.metric.Irect_mean_A,'Po_avg',op.Vo*raw.metric.Irect_mean_A, ...
    'Ir_rms',raw.metric.iLine_rms_A,'Ir_peak',peak,'waveform',waveform, ...
    'harmonics',waveform_harmonics(waveform,31),'solve_time',elapsed,'residual',residual, ...
    'converged',converged,'validity_flag',flag,'state_size',stateSize,'algebraic_unknowns',unknowns, ...
    'Pin',raw.metric.Pin_W,'PRin',raw.metric.PRin_W,'power_residual',raw.metric.power_residual_W, ...
    'blocked_fraction',raw.metric.all_blocked_fraction,'raw',raw);
result.physical_state_size=6;
result.state_size_definition='HOGA: independent real current Fourier plus outer DC/event coordinates before linear elimination; reference: physical ODE states';
end
