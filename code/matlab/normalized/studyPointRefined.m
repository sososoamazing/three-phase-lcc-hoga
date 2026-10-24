function [record,solution]=studyPointRefined(root,Vo,fn,k,seed,stage)
% Real HOGA solves only. Unresolved points retain NaN and all failed attempts.
if nargin<4, k=.2; end
if nargin<5, seed=struct(); end
if nargin<6, stage='A'; end
p=lcc3v2Params('original_reduced');fr=1/(2*pi*sqrt(p.Ls*p.Cs));
p.fs=fn*fr;p.Cp_delta=k*p.Cs;
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
timer=tic;comparison=struct();
candidates={};labels={};
if ~isempty(fieldnames(seed)),candidates{end+1}=seed;labels{end+1}='adaptive continuation';end
files=dir(fullfile(root,'data','A',sprintf('*_F%06.3f_K%06.3f.mat',fn,k)));
dist=[];neighbors={};failed=struct();
for fileIndex=1:numel(files)
    d=load(fullfile(files(fileIndex).folder,files(fileIndex).name),'record','solution');
    if d.record.accepted && d.record.Io_A>1e-8
        neighbors{end+1}=d.solution;dist(end+1)=abs(d.record.Vo_V-Vo);
    elseif abs(d.record.Vo_V-Vo)<1e-8 && isfield(d.solution,'event_schedule')
        failed=d.solution;
    end
end
[~,order]=sort(dist);
for j=1:min(2,numel(order)),candidates{end+1}=neighbors{order(j)};labels{end+1}='new-scan HOGA voltage neighbor';end
if isfield(failed,'metric') && isfield(failed.metric,'min_diode_current_signed_A')
    try
        proposal=studyDiscover(failed,p,Vo,'release');
        alternative=struct('event_schedule',proposal,'method','Fourier reaction-release hypothesis', ...
            'e_initial_alpha_beta',failed.e_initial_alpha_beta,'Vo_V',Vo,'params',p);
        candidates{end+1}=alternative;labels{end+1}='failed-candidate signed-reaction release';
    catch
        % Unsupported topology proposals are not accepted as data.
    end
end
bank=readtable(fullfile(root,'audit','seed_bank.csv'),TextType='string');
distance=abs(bank.Vo-Vo)/250+abs(log(bank.fs/p.fs))*3+abs(log(bank.Cp/p.Cp_delta));
[~,ix]=sort(distance);d=load(bank.path(ix(1)));
if bank.kind(ix(1))=="point",s=d.point.solution;else,s=d.solution;end
candidates{end+1}=s;labels{end+1}='historical HOGA seed';
candidates{end+1}=struct();labels{end+1}='fresh_faces';
candidates{end+1}=struct();labels{end+1}='fresh_support_coalesced';
discovery=struct();
for candidateIndex=1:numel(candidates)
    p.researchTimer=tic;p.maxPointSeconds=35;
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
        if (~orderPass(comparison,fine) || ~fine.physical_guard_pass) && fine.converged_algebraic && ...
                fine.metric.normal_max_V<.02*(Vo+2*p.Vf_rect)
            higher=fixOpen(studyHoga(p,Vo,63,fine));
            attempts(end+1)=attempt(labels{candidateIndex},higher,''); %#ok<AGROW>
            comparison=lcc3v2Compare(higher,fine);fine=higher;
        end
        solution=fine;
        record.physical=fine.physical_guard_pass;record.order_pass=orderPass(comparison,fine);
        record.H=fine.H;
        if record.physical && record.order_pass
            record.accepted=true;break
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
target=fullfile(root,'data',stage,sprintf('V%07.2f_F%06.3f_K%06.3f.mat',Vo,fn,k));
save(target,'record','solution','comparison','attempts','p','-v7');
fprintf('POINT %s V=%g fn=%.4f k=%.3g ok=%d H=%g Io=%.6g Im=%.6g t=%.2f\n', ...
    stage,Vo,fn,k,record.accepted,record.H,record.Io_A,record.Im_A,record.elapsed_s);
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
    f=@(tau)-abs(real(exp(1i*2*pi*tau*h)*coeff(j,:).'));
    [~,negative]=fminbnd(f,t(ix)-1/8192,t(ix)+1/8192,optimset('TolX',1e-13,'Display','off'));
    peaks(j)=max(peaks(j),-negative);
end
change=max((peaks-sample)./max(peaks,1e-12));im1=max(2*abs(coeff(:,s.h==1)));
end
