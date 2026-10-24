function [record,solution]=studyPointRecovery(root,Vo,fn,k,extraSeeds,cache,stage)
% Recovery solve for a previously unresolved point. Real HOGA solves only.
% Same physical guard and same H15->31->63 order check as studyPointRefined;
% only the SEED STRATEGY is extended:
%   (a) same k, same Vo, nearest fn          - cross-frequency continuation
%   (b) same k, same fn, nearest Vo          - voltage continuation, now also
%                                              seeding from stage B and C
%   (c) same k, nearest (Vo,fn) in 2D        - diagonal continuation
%   (d) in-group stage-C solutions solved earlier in this run (chained)
%   (e) historical bank, (f) fresh faces / support coalesced
% The point is written to data/<stage>/ with the same file naming, so nothing
% already on disk is overwritten (the driver skips existing files).
if nargin<5,extraSeeds={};end
if nargin<6,cache=containers.Map('KeyType','char','ValueType','any');end
if nargin<7,stage='C';end
p=lcc3v2Params('original_reduced');fr=1/(2*pi*sqrt(p.Ls*p.Cs));
p.fs=fn*fr;p.Cp_delta=k*p.Cs;
% Raised Newton limits for recovery only; all physical guards are unchanged.
p.solverMaxIterations=400;p.solverMaxFunctionEvaluations=8000;
record=struct('stage',stage,'Vo_V',Vo,'M',Vo/(p.n_sp*p.Vin),'fn',fn,'fs_Hz',p.fs, ...
    'k_delta',k,'k_star',3*k,'Cp_delta_nF',p.Cp_delta*1e9, ...
    'accepted',false,'physical',false,'order_pass',false,'status','UNRESOLVED', ...
    'H',NaN,'Io_A',NaN,'Jo',NaN,'Im_A',NaN,'Jm',NaN,'Irms_A',NaN,'Jrms',NaN, ...
    'Im_a_A',NaN,'Im_b_A',NaN,'Im_c_A',NaN,'Irms_a_A',NaN,'Irms_b_A',NaN,'Irms_c_A',NaN, ...
    'Im1_A',NaN,'Pout_W',NaN,'CCM',false,'blocked_fraction',NaN, ...
    'comm1_A',NaN,'comm2_A',NaN,'comm3_A',NaN,'comm4_A',NaN,'comm5_A',NaN,'comm6_A',NaN, ...
    'minimum_comm_margin_A',NaN,'all_six_polarity',false,'zvs_certified',false, ...
    'event_residual_scaled',NaN,'normal_max_V',NaN,'diode_voltage_violation_V',NaN, ...
    'power_residual_relative',NaN,'closure_scaled',NaN,'Io_H_change',NaN,'Im_H_change',NaN, ...
    'Irms_H_change',NaN,'peak_grid_refinement',NaN,'elapsed_s',NaN,'attempt_count',0,'error','');
solution=struct();attempts=struct('seed',{},'H',{},'guard',{},'Io_A',{},'Im_A',{},'error',{});
chosenSeed='';
timer=tic;comparison=struct();
candidates={};labels={};

% ---- (d) solutions found earlier in the same group during this run
for j=1:numel(extraSeeds)
    candidates{end+1}=extraSeeds{j}.solution; %#ok<AGROW>
    labels{end+1}=sprintf('stage-C chain V=%g fn=%.3f',extraSeeds{j}.Vo,extraSeeds{j}.fn); %#ok<AGROW>
end

% ---- (a) cross-frequency, (b) voltage, (c) diagonal: scan all stages once
entries=scanCatalog(root);
if ~isempty(entries)
    sameK=find(abs([entries.k]-k)<1e-9);
    % (a) same Vo, different fn
    pick=[];score=[];
    for e=sameK
        if abs(entries(e).Vo-Vo)<0.51 && abs(entries(e).fn-fn)>1e-9
            pick(end+1)=e;score(end+1)=abs(entries(e).fn-fn); %#ok<AGROW>
        end
    end
    [~,order]=sort(score);addedCandidates=addSeeds(entries(pick(order)),2,candidates,labels,cache,'cross-frequency');
    candidates=addedCandidates.candidates;labels=addedCandidates.labels;
    % (b) same fn, different Vo
    pick=[];score=[];
    for e=sameK
        if abs(entries(e).fn-fn)<1e-9 && abs(entries(e).Vo-Vo)>0.51
            pick(end+1)=e;score(end+1)=abs(entries(e).Vo-Vo); %#ok<AGROW>
        end
    end
    [~,order]=sort(score);addedCandidates=addSeeds(entries(pick(order)),2,candidates,labels,cache,'voltage-chain');
    candidates=addedCandidates.candidates;labels=addedCandidates.labels;
    % (c) 2D nearest, same k
    score=abs([entries(sameK).Vo]-Vo)/100+3*abs([entries(sameK).fn]-fn);
    [~,order]=sort(score);addedCandidates=addSeeds(entries(sameK(order)),1,candidates,labels,cache,'diagonal-neighbour');
    candidates=addedCandidates.candidates;labels=addedCandidates.labels;
end

% ---- (e) historical bank
bank=readtable(fullfile(root,'audit','seed_bank.csv'),TextType='string');
distance=abs(bank.Vo-Vo)/250+abs(log(bank.fs/p.fs))*3+abs(log(bank.Cp/p.Cp_delta));
[~,ix]=sort(distance);
d=load(bank.path(ix(1)));
if bank.kind(ix(1))=="point",s=d.point.solution;else,s=d.solution;end
candidates{end+1}=s;labels{end+1}='historical HOGA seed';
% ---- (f) fresh topology proposals
candidates{end+1}=struct();labels{end+1}='fresh_faces';
candidates{end+1}=struct();labels{end+1}='fresh_support_coalesced';

discovery=struct();
for candidateIndex=1:numel(candidates)
    p.researchTimer=tic;p.maxPointSeconds=90;
    try
        seed=candidates{candidateIndex};
        if isempty(fieldnames(seed))
            if isempty(fieldnames(discovery)),discovery=studyLegacy(p,Vo,7,[]);end
            strategy=erase(labels{candidateIndex},'fresh_');
            schedule=studyDiscover(discovery,p,Vo,strategy);g=lcc3v2Geometry();
            seed=struct('event_schedule',schedule,'method','Fourier fresh topology proposal', ...
                'e_initial_alpha_beta',g.U'*discovery.wave.vSec_V(1,:).','Vo_V',Vo,'params',p);
        else
            seed.e_initial_alpha_beta=seed.e_initial_alpha_beta*(Vo+2*p.Vf_rect)/(seed.Vo_V+2*seed.params.Vf_rect);
            seed.Vo_V=Vo;
        end
        low=fixOpen(studyHoga(p,Vo,15,seed));
        attempts(end+1)=attempt(labels{candidateIndex},low,''); %#ok<AGROW>
        fine=fixOpen(studyHoga(p,Vo,31,low));
        attempts(end+1)=attempt(labels{candidateIndex},fine,''); %#ok<AGROW>
        comparison=lcc3v2Compare(fine,low);
        if (~orderPass(comparison,fine)||~fine.physical_guard_pass) && fine.converged_algebraic && ...
                fine.metric.normal_max_V<.02*(Vo+2*p.Vf_rect)
            higher=fixOpen(studyHoga(p,Vo,63,fine));
            attempts(end+1)=attempt(labels{candidateIndex},higher,''); %#ok<AGROW>
            comparison=lcc3v2Compare(higher,fine);fine=higher;
        end
        solution=fine;
        record.physical=fine.physical_guard_pass;record.order_pass=orderPass(comparison,fine);
        record.H=fine.H;
        if record.physical && record.order_pass
            record.accepted=true;chosenSeed=labels{candidateIndex};break
        end
    catch err
        attempts(end+1)=struct('seed',labels{candidateIndex},'H',NaN,'guard',false, ...
            'Io_A',NaN,'Im_A',NaN,'error',getReport(err,'extended','hyperlinks','off')); %#ok<AGROW>
        record.error=err.message;
    end
end
if record.accepted
    [peaks,refine,im1]=refinedPeaks(solution);kernel=extractLossKernels(solution);
    ir=solution.metric.iLine_rms_A;record.Io_A=solution.metric.Irect_mean_A;
    record.Im_A=max(peaks);record.Im1_A=im1;record.Irms_A=max(ir);
    record.Im_a_A=peaks(1);record.Im_b_A=peaks(2);record.Im_c_A=peaks(3);
    record.Irms_a_A=ir(1);record.Irms_b_A=ir(2);record.Irms_c_A=ir(3);
    record.Pout_W=Vo*record.Io_A;Z0=sqrt(p.Ls/p.Cs);
    record.Jo=record.Io_A*p.n_sp*Z0/p.Vin;
    record.Jm=record.Im_A*Z0/p.Vin;record.Jrms=record.Irms_A*Z0/p.Vin;
    widths=diff(solution.event_schedule.edges);
    record.blocked_fraction=sum(widths(cellfun(@isempty,solution.event_schedule.active)));
    record.CCM=record.blocked_fraction<1e-8;
    record.status='ACCEPTED_CCM';
    if ~record.CCM,record.status='ACCEPTED_DCM';end
    if record.blocked_fraction>.999999
        record.status='OPEN_PERIODIC_FAMILY_NOT_REACHABILITY';
    end
    margins=kernel.MOS_Ioff_signed_A;
    for j=1:6,record.(sprintf('comm%d_A',j))=margins(j);end
    record.minimum_comm_margin_A=min(margins);
    record.all_six_polarity=all(margins>1e-8);
    record.event_residual_scaled=solution.metric.event_equation_residual_V/(Vo+2*p.Vf_rect);
    record.normal_max_V=solution.metric.normal_max_V;
    record.diode_voltage_violation_V=solution.metric.diode_voltage_violation_max_V;
    record.power_residual_relative=solution.metric.power_relative_residual;
    record.closure_scaled=solution.closure_scaled;
    record.Io_H_change=comparison.Irect_mean_A_relative;
    record.Im_H_change=comparison.iLine_peak_A_relative;
    record.Irms_H_change=comparison.iLine_rms_A_relative;
    record.peak_grid_refinement=refine;record.error='';
end
record.elapsed_s=toc(timer);record.attempt_count=numel(attempts);
folder=fullfile(root,'data',stage);
if ~isfolder(folder),mkdir(folder);end
target=fullfile(folder,sprintf('V%07.2f_F%06.3f_K%06.3f.mat',Vo,fn,k));
save(target,'record','solution','comparison','attempts','p','chosenSeed','-v7');
fprintf('RECOVERY %s V=%g fn=%.4f k=%.3g ok=%d H=%g Io=%.6g Im=%.6g seed=%s t=%.1f\n', ...
    stage,Vo,fn,k,record.accepted,record.H,record.Io_A,record.Im_A,chosenSeed,record.elapsed_s);
end

% ------------------------------------------------------------------ helpers
function out=addSeeds(entries,maxAdd,candidates,labels,cache,prefix)
out.candidates=candidates;out.labels=labels;added=0;
for e=1:numel(entries)
    if added>=maxAdd,break;end
    entry=entries(e);
    if isKey(cache,entry.path)
        d=cache(entry.path);
    else
        try
            d=load(entry.path,'record','solution');
        catch
            continue
        end
        cache(entry.path)=d;
    end
    if ~isfield(d,'record')||~d.record.accepted,continue;end
    out.candidates{end+1}=d.solution;
    out.labels{end+1}=sprintf('%s %s V=%g fn=%.3f',prefix,entry.stage,entry.Vo,entry.fn);
    added=added+1;
end
end

function entries=scanCatalog(root)
entries=struct('Vo',{},'fn',{},'k',{},'path',{},'stage',{});
stages={'A','B','C'};
for s=1:numel(stages)
    files=dir(fullfile(root,'data',stages{s},'V*_F*_K*.mat'));
    for i=1:numel(files)
        tok=regexp(files(i).name,'^V(?<v>[\d.]+)_F(?<f>[\d.]+)_K(?<k>[\d.]+)\.mat$','names');
        if isempty(tok),continue;end
        entries(end+1)=struct('Vo',str2double(tok.v),'fn',str2double(tok.f), ...
            'k',str2double(tok.k),'path',fullfile(files(i).folder,files(i).name),'stage',stages{s}); %#ok<AGROW>
    end
end
end

function a=attempt(label,s,errorText)
a=struct('seed',label,'H',s.H,'guard',s.physical_guard_pass, ...
    'Io_A',s.metric.Irect_mean_A,'Im_A',max(s.metric.iLine_peak_A),'error',errorText);
end

function s=fixOpen(s)
s=integrateHogaInput(s);
if contains(s.branch,'all_blocked')
    p=s.params;Vd=s.Vo_V+2*p.Vf_rect;
    s.physical_guard_pass=s.converged_algebraic && s.metric.normal_max_V<=p.physical_voltage_rel*Vd && ...
        s.metric.diode_voltage_violation_max_V<=p.physical_voltage_rel*Vd && ...
        max(abs(s.wave.jSecondary_A),[],'all')<1e-7 && abs(s.metric.Irect_mean_A)<1e-8 && ...
        s.metric.power_relative_residual<=p.physical_power_rel;
end
end

function pass=orderPass(c,s)
io=c.Irect_mean_A_relative;
if contains(s.branch,'all_blocked') && c.Irect_mean_A_absolute<1e-8,io=0;end
jr=c.jSec_rms_A_relative;
if contains(s.branch,'all_blocked') && c.jSec_rms_A_absolute<1e-8,jr=0;end
pass=io<.005 && c.iLine_rms_A_relative<.005 && c.iLine_peak_A_relative<.01 && jr<.005 && ...
    c.event_topology_match && c.event_time_max_T<.001;
end

function [peaks,change,im1]=refinedPeaks(s)
g=lcc3v2Geometry();coeff=g.U*s.coeff.i_alpha_beta;h=s.h.';t=(0:8191)'/8192;
values=real(exp(1i*2*pi*t*h)*coeff.');sample=max(abs(values),[],1);peaks=sample;
for j=1:3
    [~,ix]=max(abs(values(:,j)));
    [~,negative]=fminbnd(@(tau)-abs(real(exp(1i*2*pi*tau*h)*coeff(j,:).')),t(ix)-1/8192,t(ix)+1/8192, ...
        optimset('TolX',1e-13,'Display','off'));
    peaks(j)=max(peaks(j),-negative);
end
change=max((peaks-sample)./max(peaks,1e-12));im1=max(2*abs(coeff(:,s.h==1)));
end
