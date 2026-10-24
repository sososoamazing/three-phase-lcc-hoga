function result=solve_hoga_accelerated(cfg,op)
% Same audited equations, vectorized assembly; HOGA-only continuation seeds.
assert(isfile(fullfile(cfg.root,'06_reports','Acceleration_Validation.csv')),'Comparison:NotValidated','Run validate_acceleration first.');
addpath(fullfile(cfg.root,'02_HOGA','accelerated'));
p=hoga_parameters(cfg,op);timer=tic;
files=dir(fullfile(cfg.root,'05_verification','data','campaign','HOGA_*.mat'));
distance=inf(size(files));seeds=cell(size(files));
for k=1:numel(files)
    d=load(fullfile(files(k).folder,files(k).name),'result','op');
    if isfield(d.result,'converged') && d.result.converged
        distance(k)=abs(d.op.Vo-op.Vo)/200+3*abs(log(d.op.fs/op.fs));seeds{k}=d.result.raw;
    end
end
[~,ix]=sort(distance);ix=ix(isfinite(distance(ix)));ix=ix(1:min(2,numel(ix)));
candidates=seeds(ix);labels={files(ix).name};
candidates=[candidates(:);{struct();struct()}];labels=[labels(:);{'fresh support';'fresh faces'}];
attempts=struct('seed',{},'elapsed_s',{},'message',{},'physical',{},'order_change',{});chosen=struct();
for k=1:numel(candidates)
    started=tic;p.researchTimer=tic;p.maxPointSeconds=40;
    message='';physical=false;change=struct();
    try
        seed=candidates{k};
        if isempty(fieldnames(seed))
            discovery=solve_three_phase_lcc_hoga(p,op.Vo,7,[]);g=lcc3v2Geometry();
            if strcmp(labels{k},'fresh support'),schedule=lcc3v2Discover(discovery,p,op.Vo,'support_coalesced');
            else,schedule=lcc3v2Discover(discovery,p,op.Vo);end
            seed=struct('event_schedule',schedule,'method','Fourier topology proposal', ...
                'Vo_V',op.Vo,'e_initial_alpha_beta',g.U'*discovery.wave.vSec_V(1,:).');
        else
            seed.e_initial_alpha_beta=seed.e_initial_alpha_beta*(op.Vo+2*p.Vf_rect)/(seed.Vo_V+2*seed.params.Vf_rect);
            seed.Vo_V=op.Vo;
        end
        low=studyHoga(p,op.Vo,15,seed);high=studyHoga(p,op.Vo,cfg.H,low);
        change=lcc3v2Compare(high,low);physical=high.physical_guard_pass;
        chosen=high;
    catch err
        message=getReport(err,'extended','hyperlinks','off');
    end
    attempts(end+1)=struct('seed',labels{k},'elapsed_s',toc(started),'message',message,'physical',physical,'order_change',change); %#ok<AGROW>
    if physical,break;end
end
% Existing V2.3 release strategy: remove a face when its signed reaction is
% negative. This is another HOGA-only hypothesis, not a reference-derived fix.
if ~physical && ~isempty(fieldnames(chosen)) && isfield(chosen.metric,'min_diode_current_signed_A') && chosen.metric.min_diode_current_signed_A < -1e-7
    started=tic;p.researchTimer=tic;p.maxPointSeconds=40;message='';change=struct();
    try
        schedule=lcc3v2Discover(chosen,p,op.Vo,'release');
        seed=struct('event_schedule',schedule,'method','Fourier signed-reaction release proposal', ...
            'Vo_V',op.Vo,'e_initial_alpha_beta',chosen.e_initial_alpha_beta);
        low=studyHoga(p,op.Vo,15,seed);high=studyHoga(p,op.Vo,cfg.H,low);
        change=lcc3v2Compare(high,low);physical=high.physical_guard_pass;chosen=high;
    catch err
        message=getReport(err,'extended','hyperlinks','off');
    end
    attempts(end+1)=struct('seed','HOGA signed-reaction release','elapsed_s',toc(started),'message',message,'physical',physical,'order_change',change);
end
out=fullfile(cfg.root,'05_verification','data','hoga_attempts');if ~isfolder(out),mkdir(out);end
attemptFile=fullfile(out,sprintf('V%d_f%d.mat',op.Vo,op.fs));
if isfile(attemptFile),attemptFile=fullfile(out,sprintf('V%d_f%d_recovery.mat',op.Vo,op.fs));end
save(attemptFile,'attempts','op','-v7');
if isempty(fieldnames(chosen)),error('Comparison:HogaAttemptsFailed','All HOGA-only topology attempts failed; see hoga_attempts.');end
result=adapt_physical_result(cfg,op,chosen,toc(timer),'HOGA');result.attempts=attempts;
result.implementation='project studyHoga vectorized assembly, four-point equivalence verified';
result.order_change=change;
end
