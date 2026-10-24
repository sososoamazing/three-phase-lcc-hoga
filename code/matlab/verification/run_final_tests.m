function run_final_tests
root=fileparts(fileparts(mfilename('fullpath')));setup_comparison(root);maxNumCompThreads(1);
results=runtests(fullfile(root,'05_verification','test_cases'));
writetable(table(string({results.Name}'),[results.Passed]',[results.Failed]',[results.Incomplete]', ...
    VariableNames={'Name','Passed','Failed','Incomplete'}),fullfile(root,'06_reports','Test_Results.csv'));
files=[dir(fullfile(root,'01_common','*.m'));dir(fullfile(root,'03_EDF','*.m'));dir(fullfile(root,'04_FHA','*.m'));dir(fullfile(root,'05_verification','*.m'))];
analysis=struct('file',{},'issues',{});
for k=1:numel(files)
    analysis(k)=struct('file',fullfile(files(k).folder,files(k).name), ...
        'issues',checkcode(fullfile(files(k).folder,files(k).name),'-struct'));
end
writeJson(fullfile(root,'06_reports','checkcode.json'),analysis);
recompute_simulink_metrics;
cfg=model_config();rows=struct([]);base=fullfile(root,'05_verification','data','campaign');
for Vo=[100 400 700 800]
    fine=load(fullfile(base,sprintf('REFERENCE_V%d_f280000.mat',Vo)),'result');
    coarse=load(fullfile(root,'00_audit','data','stage1_run02',sprintf('reference_V%d.mat',Vo)),'reference');
    r=fine.result.raw;comparison=lcc3v2Compare(r,coarse.reference);
    hd=load(fullfile(root,'00_audit','data','stage1_run02',sprintf('original_V%d_H31.mat',Vo)),'hoga');
    h15=load(fullfile(root,'00_audit','data','stage1_run02',sprintf('original_V%d_H15.mat',Vo)),'hoga');
    h9=load(fullfile(root,'00_audit','data','stage1_run02',sprintf('original_V%d_H9.mat',Vo)),'hoga');
    change=lcc3v2Compare(hd.hoga,h15.hoga);change.previous_change=lcc3v2Compare(h15.hoga,h9.hoga);
    acceptance=lcc3v2Accept(hd.hoga,r,coarse.reference,comparison,change,hoga_parameters(cfg,struct('fs',cfg.fs)));
    peak=fourier_current_peaks(hd.hoga);dense=lcc3v2Evaluate(hd.hoga,(0:32767)'/32768);g=lcc3v2Geometry();
    peakGridError=max(abs(peak-max(abs(dense(:,1:2)*g.U'),[],1)));
    rows=[rows struct('Vo',Vo,'reference_Io_change',comparison.Irect_mean_A_relative, ...
        'reference_peak_change',comparison.iLine_peak_A_relative,'event_change_T',comparison.event_time_max_T, ...
        'reference_fine_valid',r.physical_guard_pass,'H31_acceptance',acceptance,'peak_grid_error_A',peakGridError)]; %#ok<AGROW>
end
writetable(struct2table(rows,AsArray=true),fullfile(root,'06_reports','Convergence_Validation.csv'));
assert(all([results.Passed]),'Comparison:TestsFailed','Inspect Test_Results.csv; do not certify failure.');
fprintf('FINAL_TESTS_COMPLETE\n');
end
function writeJson(file,value)
fid=fopen(file,'w','n','UTF-8');fprintf(fid,'%s',jsonencode(value,PrettyPrint=true));fclose(fid);
end
