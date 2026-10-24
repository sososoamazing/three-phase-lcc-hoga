function postprocess_comparison(makeFigures)
% Read saved numerical evidence only. No fitting, phase alignment or re-solving.
if nargin<1,makeFigures=true;end
root=fileparts(fileparts(mfilename('fullpath')));setup_comparison(root);cfg=model_config();
data=fullfile(root,'05_verification','data');report=fullfile(root,'06_reports');
figdir=fullfile(root,'05_verification','figures');
files=dir(fullfile(data,'campaign','*.mat'));records=struct([]);errors=struct([]);cache=struct();openFixes=struct([]);
for k=1:numel(files)
    d=load(fullfile(files(k).folder,files(k).name));
    recovery=fullfile(data,'recovery',files(k).name);
    if isfile(recovery)
        trial=load(recovery);if trial.record.converged,d=trial;end
    end
    r=d.record;
    if strcmp(r.model,'HOGA') && isfield(d.result,'raw')
        if contains(d.result.raw.branch,'all_blocked_nonunique')
            % Recompute diagnostics only; keep historical numerical solves untouched.
            before=d.result.raw.metric;
            d.result=adapt_physical_result(cfg,d.op,d.result.raw,d.result.solve_time,'HOGA');
            r.power_residual=d.result.power_residual;r.converged=d.result.converged;r.validity=d.result.validity_flag;
            openFixes=[openFixes struct('Vo',r.Vo,'fs',r.fs,'old_Pin_W',before.Pin_W, ...
                'old_power_residual_W',before.power_residual_W,'old_power_relative',before.power_relative_residual, ...
                'new_Pin_W',d.result.Pin,'new_PRin_W',d.result.PRin,'new_power_residual_W',d.result.power_residual, ...
                'new_guard',d.result.converged,'coefficients_changed',false)]; %#ok<AGROW>
        end
        r.algebraic_unknowns=numel(d.result.raw.event_schedule.edges);
        r.state_size=4*d.result.raw.H+r.algebraic_unknowns;
    end
    records=[records r]; %#ok<AGROW>
    key=sprintf('%s_V%d_f%d',r.model,r.Vo,r.fs);cache.(key)=d;
end
assert(numel(records)==80,'Comparison:Incomplete','Expected 20 points x 4 methods; retain partial data and resume campaign.');
writetable(struct2table(records,AsArray=true),fullfile(report,'Point_Results.csv'));
writetable(struct2table(openFixes,AsArray=true),fullfile(report,'Open_Branch_Fix.csv'));
ports=struct([]);
for k=1:numel(records)
    rr=records(k);r=cache.(sprintf('%s_V%d_f%d',rr.model,rr.Vo,rr.fs)).result;
    if ~rr.converged,continue;end
    w=r.waveform;t=w.tau;gate=double([t<.5,t<1/6 | t>=2/3,t>=1/3 & t<5/6]);
    dc=sum(gate.*w.i_A,2);pinPhase=mean((cfg.Vin-cfg.Rin*dc).*gate.*w.i_A,1);
    at=(0:5)'/6;
    if strcmp(rr.model,'HOGA'),x=lcc3v2Evaluate(r.raw,at);g=lcc3v2Geometry();edgeCurrent=x(:,1:2)*g.U';
    else,edgeCurrent=interp1([t;1],[w.i_A;w.i_A(1,:)],at);end
    edges=edgeCurrent(sub2ind([6 3],(1:6)',[1;2;3;1;2;3]));
    ports=[ports struct('model',rr.model,'Vo',rr.Vo,'fs',rr.fs, ...
        'Irms_A',r.Ir_rms(1),'Irms_B',r.Ir_rms(2),'Irms_C',r.Ir_rms(3), ...
        'Ipeak_A',r.Ir_peak(1),'Ipeak_B',r.Ir_peak(2),'Ipeak_C',r.Ir_peak(3), ...
        'Cp_peak_edge1_V',max(abs(w.vDelta_V(:,1))),'Cp_peak_edge2_V',max(abs(w.vDelta_V(:,2))), ...
        'Cp_peak_edge3_V',max(abs(w.vDelta_V(:,3))), ...
        'Pin_phase_A_W',pinPhase(1),'Pin_phase_B_W',pinPhase(2),'Pin_phase_C_W',pinPhase(3), ...
        'sampled_Pin_minus_exact_W',sum(pinPhase)-(r.Pin-r.PRin), ...
        'gate_t0_iA_A',edges(1),'gate_t1_6_iB_A',edges(2),'gate_t2_6_iC_A',edges(3), ...
        'gate_t3_6_iA_A',edges(4),'gate_t4_6_iB_A',edges(5),'gate_t5_6_iC_A',edges(6))]; %#ok<AGROW>
end
writetable(struct2table(ports,AsArray=true),fullfile(report,'Port_Metrics.csv'));
models={'HOGA','EDF','FHA'};
for k=1:numel(records)
    r=records(k);if strcmp(r.model,'REFERENCE'),continue;end
    d=cache.(sprintf('%s_V%d_f%d',r.model,r.Vo,r.fs));
    ref=cache.(sprintf('REFERENCE_V%d_f%d',r.Vo,r.fs));
    errors=[errors compare(r,d.result,ref.result,'EVENT_ODE',cfg)]; %#ok<AGROW>
end
simulink=struct();simchecks=struct([]);
for Vo=cfg.typical_voltages
    fine=load(fullfile(data,sprintf('simulink_V%d_fine_integrated.mat',Vo)));
    coarse=load(fullfile(data,sprintf('simulink_V%d_coarse_integrated.mat',Vo)));
    sr=struct('Io_avg',fine.record.Io,'Ir_rms',fine.record.Irms,'Ir_peak',fine.record.Ipeak, ...
        'waveform',fine.waveform,'converged',strcmp(fine.record.status,'PASS'));
    ref=cache.(sprintf('REFERENCE_V%d_f%d',Vo,cfg.fs));
    sr.blocked_fraction=ref.result.blocked_fraction;
    simulink.(sprintf('V%d',Vo))=sr;
    simchecks=[simchecks struct('Vo',Vo,'Io_coarse',coarse.record.Io,'Io_fine',fine.record.Io, ...
        'ref_Io',ref.result.Io_avg,'ref_difference_A',fine.record.Io-ref.result.Io_avg, ...
        'ref_difference_percent',100*(fine.record.Io/ref.result.Io_avg-1), ...
        'refinement_Io_A',fine.record.Io-coarse.record.Io,'periodic_relative',fine.record.periodic_relative, ...
        'Vo_error_V',fine.record.Vo_error_V)]; %#ok<AGROW>
    for m=1:3
        d=cache.(sprintf('%s_V%d_f%d',models{m},Vo,cfg.fs));
        errors=[errors compare(d.record,d.result,sr,'SIMULINK_FINE',cfg)]; %#ok<AGROW>
    end
end
writetable(struct2table(simchecks,AsArray=true),fullfile(report,'Simulink_Refinement.csv'));
T=struct2table(errors,AsArray=true);writetable(T,fullfile(report,'Point_Errors.csv'));
statistics=struct([]);
for ref={'EVENT_ODE','SIMULINK_FINE'}
    for scope={'ALL','CCM','OUTSIDE_TARGET_CCM','VOLTAGE_SWEEP'}
        for model=models
            use=strcmp(T.reference,ref{1}) & strcmp(T.model,model{1});
            if strcmp(scope{1},'CCM'),use=use & ~T.outside_CCM;
            elseif strcmp(scope{1},'OUTSIDE_TARGET_CCM'),use=use & T.outside_CCM;
            elseif strcmp(scope{1},'VOLTAGE_SWEEP'),use=use & T.fs==cfg.fs;end
            a=T(use,:);valid=a.valid;n=sum(valid);
            statistics=[statistics struct('reference',ref{1},'scope',scope{1},'model',model{1}, ...
                'points',height(a),'valid_points',n,'invalid_points',height(a)-n, ...
                'Io_MAE_A',mean(abs(a.Io_error_A(valid))),'Io_NRMSE_1A',sqrt(mean(a.Io_error_A(valid).^2))/cfg.normalization_Io, ...
                'Io_max_abs_A',maxOrNaN(abs(a.Io_error_A(valid))), ...
                'Irms_MAE_A',mean(a.Irms_MAE_A(valid)),'Irms_max_abs_A',maxOrNaN(a.Irms_max_abs_A(valid)), ...
                'Ipeak_MAE_A',mean(a.Ipeak_MAE_A(valid)),'Ipeak_max_abs_A',maxOrNaN(a.Ipeak_max_abs_A(valid)), ...
                'wave_MAE_A',mean(a.wave_MAE_A(valid)),'wave_NRMSE_Ibase',sqrt(mean(a.wave_NRMSE_Ibase(valid).^2)), ...
                'wave_max_abs_A',maxOrNaN(a.wave_max_abs_A(valid)))]; %#ok<AGROW>
        end
    end
end
writetable(struct2table(statistics,AsArray=true),fullfile(report,'Error_Statistics.csv'));
efficiency=struct([]);
for model=[{'REFERENCE'} models]
    rr=records(strcmp({records.model},model{1}));
    efficiency=[efficiency struct('model',model{1},'attempted',numel(rr),'converged',sum([rr.converged]), ...
        'sum_recorded_s',sum([rr.time_s],'omitnan'),'median_s',median([rr.time_s],'omitnan'), ...
        'max_s',max([rr.time_s]),'max_scaled_residual',max([rr.residual]), ...
        'max_abs_power_residual_W',max(abs([rr.power_residual])), ...
        'state_size_min',min([rr.state_size]),'state_size_max',max([rr.state_size]), ...
        'algebraic_unknowns_max',max([rr.algebraic_unknowns]))]; %#ok<AGROW>
end
writetable(struct2table(efficiency,AsArray=true),fullfile(report,'Efficiency_Statistics.csv'));
if ~makeFigures
    orderRows=table2struct(readtable(fullfile(report,'Harmonic_Convergence.csv')));
    save(fullfile(report,'processed_evidence.mat'),'records','errors','statistics','efficiency','simchecks','orderRows','cfg','-v7');
    fprintf('METRICS_REFRESH_COMPLETE\n');return
end
% MATLAB figures: one axes/figure, stable phase and parameter labels.
set(groot,'defaultFigureVisible','off','defaultAxesFontName','Arial','defaultAxesFontSize',11);
set(groot,'defaultLineLineWidth',1.5);
names={'REFERENCE','HOGA','EDF','FHA'};labels={'Independent event ODE','HOGA H31','EDF','FHA'};
colors=[.1 .1 .1;.05 .35 .75;.85 .35 .08;.45 .2 .65];styles={'-','--','-.',':'};
for quantity={'Io','Io_error','Irms','Po'}
    newFigure();q=quantity{1};
    for m=1:4
        if strcmp(q,'Io_error') && m==1,continue;end
        y=zeros(size(cfg.Vo_points));
        for k=1:numel(y)
            r=cache.(sprintf('%s_V%d_f%d',names{m},cfg.Vo_points(k),cfg.fs)).result;
            y(k)=metric(r,q);if ~r.converged,y(k)=NaN;end
            if strcmp(q,'Io_error'),y(k)=r.Io_avg-cache.(sprintf('REFERENCE_V%d_f%d',cfg.Vo_points(k),cfg.fs)).result.Io_avg;end
            if ~r.converged,y(k)=NaN;end
        end
        plot(cfg.Vo_points,y,styles{m},'Color',colors(m,:),'DisplayName',labels{m});
    end
    if ~strcmp(q,'Io_error')
        y=zeros(size(cfg.typical_voltages));
        for k=1:numel(y),r=simulink.(sprintf('V%d',cfg.typical_voltages(k)));r.Po_avg=cfg.typical_voltages(k)*r.Io_avg;y(k)=metric(r,q);end
        plot(cfg.typical_voltages,y,'ko','LineWidth',1.3,'DisplayName','Simulink (3 sampled points)');
    end
    xlabel('Output voltage (V)');ylabel(quantityLabel(q));
    title({'50 V, 280 kHz; Ls 4.7 uH, Cs 135 nF, Cp(delta) 27 nF, n=4','800 V includes blocked intervals; frozen-output test'});
    finish(['voltage_' q]);
end
for Vo=cfg.typical_voltages
    for q={'i_A','vDelta_V'}
        for phase=1:3
            newFigure();
            for m=1:4
                w=cache.(sprintf('%s_V%d_f%d',names{m},Vo,cfg.fs)).result.waveform;
                plot(w.tau,w.(q{1})(:,phase),styles{m},'Color',colors(m,:),'DisplayName',labels{m});
            end
            w=simulink.(sprintf('V%d',Vo)).waveform;
            plot(w.tau(1:128:end),w.(q{1})(1:128:end,phase),'ko','MarkerSize',3,'DisplayName','Simulink');
            xlabel('Phase t/T (A upper gate rises at 0)');
            if strcmp(q{1},'i_A'),ylabel(sprintf('Phase %c resonant current (A)','A'+phase-1));
            else,ylabel(sprintf('Delta edge %d capacitor voltage (V)',phase));end
            title(sprintf('Vo=%d V, fs=280 kHz; Vin=50 V, n=4',Vo));
            finish(sprintf('wave_%s_V%d_phase%d',q{1},Vo,phase));
        end
    end
    newFigure();
    for m=1:4
        h=cache.(sprintf('%s_V%d_f%d',names{m},Vo,cfg.fs)).result.harmonics;
        semilogy(h.order(2:end),max(1e-8,h.i_peak(2:end,1)),styles{m},'Color',colors(m,:),'DisplayName',labels{m});
    end
    h=waveform_harmonics(simulink.(sprintf('V%d',Vo)).waveform,31);
    semilogy(h.order(2:end),max(1e-8,h.i_peak(2:end,1)),'ko','MarkerSize',3,'DisplayName','Simulink');
    set(gca,'YScale','log');xlabel('Harmonic order');ylabel('Phase A positive-order peak amplitude (A)');
    title(sprintf('Vo=%d V, fs=280 kHz; FFT/N, amplitude=2|Xk|; floor 1e-8 A',Vo));finish(sprintf('spectrum_V%d',Vo));
    for q={'Io','Irms'}
        newFigure();
        for m=1:4
            y=NaN(size(cfg.frequency_points));out=false(size(y));
            for k=1:numel(y)
                tag=sprintf('%s_V%d_f%d',names{m},Vo,cfg.frequency_points(k));d=cache.(tag);
                if d.record.converged,y(k)=metric(d.result,q{1});end
                out(k)=cache.(sprintf('REFERENCE_V%d_f%d',Vo,cfg.frequency_points(k))).result.blocked_fraction>1e-5;
            end
            plot(cfg.frequency_points/1e3,y,styles{m},'Color',colors(m,:),'DisplayName',labels{m});
            plot(cfg.frequency_points(out)/1e3,y(out),'x','Color',colors(m,:),'HandleVisibility','off','MarkerSize',9);
        end
        xlabel('Switching frequency (kHz)');ylabel(quantityLabel(q{1}));
        title(sprintf('Vo=%d V, Vin=50 V; x marks outside target CCM (event ODE)',Vo));
        finish(sprintf('frequency_%s_V%d',q{1},Vo));
    end
end
orderRows=struct([]);
for Vo=[100 400 700 800]
    rr=cache.(sprintf('REFERENCE_V%d_f%d',Vo,cfg.fs)).result;
    for H=[1 3 5 7 9 15 31]
        d=load(fullfile(root,'00_audit','data','stage1_run02',sprintf('original_V%d_H%d.mat',Vo,H)));
        r=adapt_physical_result(cfg,struct('Vo',Vo,'fs',cfg.fs),d.hoga,d.elapsed,'HOGA');
        er=compare(struct('model','HOGA','Vo',Vo,'fs',cfg.fs),r,rr,'EVENT_ODE',cfg);
        orderRows=[orderRows struct('Vo',Vo,'H',H,'Io_error_A',er.Io_error_A,'Irms_max_error_A',er.Irms_max_abs_A, ...
            'peak_max_error_A',er.Ipeak_max_abs_A,'wave_NRMSE_Ibase',er.wave_NRMSE_Ibase, ...
            'time_s',d.elapsed,'residual',r.residual,'kvl_rms_V',d.hoga.metric.kvl_rms_V)]; %#ok<AGROW>
    end
    rows=orderRows([orderRows.Vo]==Vo);
    newFigure();semilogy([rows.H],max(1e-12,abs([rows.Io_error_A])),'o-','DisplayName','|Io error| / 1 A');
    semilogy([rows.H],max(1e-12,[rows.wave_NRMSE_Ibase]),'s-','DisplayName','Current waveform NRMSE / Ibase');
    semilogy([rows.H],max(1e-12,[rows.peak_max_error_A]/cfg.normalization_Ir),'d-','DisplayName','Peak error / Ibase');
    set(gca,'YScale','log');xlabel('Highest retained order H');ylabel('Normalized error (dimensionless)');
    title(sprintf('Vo=%d V, 280 kHz; Ibase=%.4g A; independent event ODE',Vo,cfg.normalization_Ir));finish(sprintf('hoga_order_error_V%d',Vo));
    newFigure();plot([rows.H],[rows.time_s],'o-','DisplayName','Measured HOGA solve');
    xlabel('Highest retained order H');ylabel('Solve time (s)');
    title(sprintf('Vo=%d V, 280 kHz; serial order continuation; includes JIT at first point',Vo));finish(sprintf('hoga_order_time_V%d',Vo));
end
writetable(struct2table(orderRows,AsArray=true),fullfile(report,'Harmonic_Convergence.csv'));
save(fullfile(report,'processed_evidence.mat'),'records','errors','statistics','efficiency','simchecks','orderRows','cfg','-v7');
fprintf('POSTPROCESS_COMPLETE figures=%d\n',numel(dir(fullfile(figdir,'*.png'))));
    function finish(name)
        grid on;box on;legend('Location','best','FontSize',9);set(gca,'Layer','top');
        exportgraphics(gcf,fullfile(figdir,[name '.png']),'Resolution',300);
        exportgraphics(gcf,fullfile(figdir,[name '.pdf']),'ContentType','vector');close(gcf);
    end
end
function newFigure
figure('Color','w','Position',[80 80 1050 640]);hold on;
end
function y=metric(r,q)
switch q
    case {'Io','Io_error'},y=r.Io_avg;
    case 'Irms',y=max(r.Ir_rms);
    case 'Po',y=r.Po_avg;
end
end
function label=quantityLabel(q)
switch q
    case 'Io',label='Average output current (A)';
    case 'Io_error',label='Output current error vs event ODE (A)';
    case 'Irms',label='Maximum phase resonant current RMS (A)';
    case 'Po',label='Average output power (W)';
end
end
function er=compare(record,r,ref,reference,cfg)
valid=isfield(r,'converged') && r.converged && ref.converged;
er=struct('reference',reference,'model',record.model,'Vo',record.Vo,'fs',record.fs,'valid',valid, ...
    'outside_CCM',ref.blocked_fraction>1e-5,'Io_reference_A',ref.Io_avg,'Io_error_A',NaN, ...
    'Irms_MAE_A',NaN,'Irms_max_abs_A',NaN,'Ipeak_MAE_A',NaN,'Ipeak_max_abs_A',NaN, ...
    'wave_MAE_A',NaN,'wave_NRMSE_Ibase',NaN,'wave_max_abs_A',NaN, ...
    'voltage_MAE_V',NaN,'voltage_NRMSE_200V',NaN);
if ~valid,return;end
er.Io_error_A=r.Io_avg-ref.Io_avg;
e=r.Ir_rms-ref.Ir_rms;er.Irms_MAE_A=mean(abs(e));er.Irms_max_abs_A=max(abs(e));
e=r.Ir_peak-ref.Ir_peak;er.Ipeak_MAE_A=mean(abs(e));er.Ipeak_max_abs_A=max(abs(e));
e=r.waveform.i_A-ref.waveform.i_A;er.wave_MAE_A=mean(abs(e),'all');
er.wave_NRMSE_Ibase=sqrt(mean(e.^2,'all'))/cfg.normalization_Ir;er.wave_max_abs_A=max(abs(e),[],'all');
e=r.waveform.vDelta_V-ref.waveform.vDelta_V;er.voltage_MAE_V=mean(abs(e),'all');er.voltage_NRMSE_200V=sqrt(mean(e.^2,'all'))/200;
end
function y=maxOrNaN(x)
if isempty(x),y=NaN;else,y=max(x);end
end
