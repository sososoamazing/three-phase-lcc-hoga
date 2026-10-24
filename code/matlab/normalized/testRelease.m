function testRelease(Vo,fn,k)
% Probe the 'release' topology hypothesis built from the point's own failed
% solution (signed diode reaction currents), which the recovery pass dropped.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'core'),fullfile(root,'legacy'),fullfile(root,'scripts'));
p=lcc3v2Params('original_reduced');fr=1/(2*pi*sqrt(p.Ls*p.Cs));
p.fs=fn*fr;p.Cp_delta=k*p.Cs;
p.solverMaxIterations=400;p.solverMaxFunctionEvaluations=8000;
failed=struct();
for st={'A','B','C'}
    f=fullfile(root,'data',st{1},sprintf('V%07.2f_F%06.3f_K%06.3f.mat',Vo,fn,k));
    if isfile(f)
        d=load(f,'record','solution');
        if ~d.record.accepted,failed=d.solution;end
    end
end
if isempty(fieldnames(failed)),fprintf('no failed solution on disk\n');return;end
fprintf('failed branch=%s conv=%d minDiodeSigned=%g\n',failed.branch,failed.converged_algebraic, ...
    failed.metric.min_diode_current_signed_A);
proposal=studyDiscover(failed,p,Vo,'release');
alt=struct('event_schedule',proposal,'method','Fourier reaction-release hypothesis', ...
    'e_initial_alpha_beta',failed.e_initial_alpha_beta,'Vo_V',Vo,'params',p);
p.researchTimer=tic;p.maxPointSeconds=150;
low=studyHoga(p,Vo,15,alt);
fprintf('H15 guard=%d conv=%d closure=%.3e branch=%s Io=%.4f\n',low.physical_guard_pass,low.converged_algebraic,low.closure_scaled,low.branch,low.metric.Irect_mean_A);
fine=studyHoga(p,Vo,31,low);
Vd=Vo+2*p.Vf_rect;
fprintf('guard terms: conv=%d diodeV=%.4g/%.4g normal=%.4g/%.4g minDiode=%.4g powerRes=%.4g ambig=%d\n', ...
    fine.converged_algebraic,fine.metric.diode_voltage_violation_max_V,p.physical_voltage_rel*Vd, ...
    fine.metric.normal_max_V,p.physical_voltage_rel*Vd,fine.metric.min_diode_current_signed_A, ...
    fine.metric.power_relative_residual,any([fine.events.ambiguous]));
disp(fine.event_schedule.active);disp(fine.events.mode_ids);
fprintf('H31 guard=%d conv=%d closure=%.3e branch=%s Io=%.4f Im=%.4f\n',fine.physical_guard_pass,fine.converged_algebraic,fine.closure_scaled,fine.branch,fine.metric.Irect_mean_A,max(fine.metric.iLine_peak_A));
end
