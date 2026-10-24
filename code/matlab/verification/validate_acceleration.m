function validate_acceleration
root=fileparts(fileparts(mfilename('fullpath')));setup_comparison(root);maxNumCompThreads(1);
addpath(fullfile(root,'02_HOGA','accelerated'));p=lcc3v2Params();
d=load(fullfile(root,'00_audit','data','stage1_run02','original_V400_H31.mat'));
profile on;baseline=lcc3v2Hoga(p,400,31,d.hoga);profile off;
prof=profile('info');save(fullfile(root,'06_reports','hoga_profile.mat'),'prof','-v7');
f=prof.FunctionTable;[~,ix]=sort([f.TotalTime],'descend');ix=ix(1:min(12,numel(ix)));
writetable(table(string({f(ix).FunctionName}'),[f(ix).TotalTime]',[f(ix).NumCalls]', ...
    VariableNames={'function','profile_total_s','calls'}),fullfile(root,'06_reports','Profile_Summary.csv'));
rows=struct([]);
for Vo=[100 400 700 800]
    old=load(fullfile(root,'00_audit','data','stage1_run02',sprintf('original_V%d_H31.mat',Vo)));
    tic;fast=studyHoga(p,Vo,31,old.hoga);elapsed=toc;
    diff=lcc3v2Compare(fast,old.hoga);
    coeffError=max(abs(fast.coeff.i_alpha_beta-old.hoga.coeff.i_alpha_beta),[],'all');
    assert(fast.physical_guard_pass && coeffError<1e-7 && diff.event_time_max_T<1e-7);
    rows=[rows struct('Vo',Vo,'max_current_coefficient_difference_A',coeffError, ...
        'Io_difference_A',fast.metric.Irect_mean_A-old.hoga.metric.Irect_mean_A, ...
        'event_difference_T',diff.event_time_max_T,'fast_seeded_time_s',elapsed)]; %#ok<AGROW>
end
studyHoga(p,400,31,d.hoga);lcc3v2Hoga(p,400,31,d.hoga);
originalTime=timeit(@()lcc3v2Hoga(p,400,31,d.hoga));
fastTime=timeit(@()studyHoga(p,400,31,d.hoga));
writetable(struct2table(rows,AsArray=true),fullfile(root,'06_reports','Acceleration_Validation.csv'));
writetable(table(originalTime,fastTime,originalTime/fastTime, ...
    VariableNames={'original_seeded_s','vectorized_seeded_s','speedup'}),fullfile(root,'06_reports','Acceleration_Benchmark.csv'));
save(fullfile(root,'06_reports','acceleration_validation.mat'),'rows','originalTime','fastTime','baseline','-v7');
fprintf('ACCELERATION_VALIDATED\n');
end
