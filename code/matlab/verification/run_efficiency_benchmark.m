function run_efficiency_benchmark
% Same process, one numeric thread, warm steady-state numeric solver timing.
root=fileparts(fileparts(mfilename('fullpath')));setup_comparison(root);maxNumCompThreads(1);
cfg=model_config();op=struct('Vo',400,'fs',cfg.fs);p=hoga_parameters(cfg,op);
startup=tic;seed=lcc3v2Solve(p,400,7);hogaSeedBuild=toc(startup);
names={'HOGA_H31_H7seed','EDF','FHA','EVENT_ODE'};
functions={@()solve_model(cfg,op,'HOGA',seed),@()edf_model(cfg,op), ...
    @()fha_model(cfg,op),@()solve_model(cfg,op,'REFERENCE')};
rows=struct([]);
for k=1:4
    tic;r=functions{k}();cold=toc;assert(r.converged);
    elapsed=timeit(functions{k});
    rows=[rows struct('model',names{k},'first_call_this_process_s',cold, ...
        'warm_timeit_s',elapsed,'external_seed_build_s',hogaSeedBuild*(k==1), ...
        'Io_A',r.Io_avg,'residual',r.residual)]; %#ok<AGROW>
end
writetable(struct2table(rows,AsArray=true),fullfile(root,'06_reports','Matched_Benchmark.csv'));
% One timing-only replay, using the already verified fine Simulink input.
d=load(fullfile(root,'05_verification','data','simulink_V400_fine_raw.mat'),'in');
addpath(fullfile(root,'05_verification','models'));
load_system(fullfile(root,'05_verification','models','lcc3_comparison.slx'));
tic;out=sim(d.in);wall=toc;
timing=out.SimulationMetadata.TimingInfo;
save(fullfile(root,'06_reports','simulink_benchmark.mat'),'timing','wall','-v7');
fid=fopen(fullfile(root,'06_reports','Simulink_Timing.json'),'w','n','UTF-8');
fprintf(fid,'%s',jsonencode(struct('wall_s',wall,'timing',timing,'scope','400V fine model, 64 periods, existing independent ODE initial state; ODE initialization cost excluded'),PrettyPrint=true));fclose(fid);
close_system('lcc3_comparison',0);fprintf('EFFICIENCY_BENCHMARK_COMPLETE\n');
end
