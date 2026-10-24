function recompute_simulink_metrics
% Reanalyze saved raw solver traces; no new Simulink run.
root=fileparts(fileparts(mfilename('fullpath')));setup_comparison(root);cfg=model_config();
for suffix={'coarse','fine'}
    rows=struct([]);
    for Vo=cfg.typical_voltages
        file=fullfile(root,'05_verification','data',sprintf('simulink_V%d_%s.mat',Vo,suffix{1}));
        d=load(file);record=d.record;waveform=d.waveform;trace=d.trace;
        endTime=trace.Io_A.time(end);begin=endTime-4/cfg.fs;
        record.Io=cycleMean(trace.Io_A,begin,endTime,1);record.Po=Vo*record.Io;
        names={'ia_A','ib_A','ic_A'};
        for k=1:3,record.Irms(k)=sqrt(cycleMean(trace.(names{k}),begin,endTime,2));end
        record.statistics_window='last 4 exact periods, native adaptive samples with interpolated endpoints';
        save(strrep(file,'.mat','_integrated.mat'),'record','waveform','cfg','-v7');
        rows=[rows record]; %#ok<AGROW>
    end
    writetable(struct2table(rows,AsArray=true),fullfile(root,'05_verification','data',['simulink_' suffix{1} '_integrated.csv']));
end
fprintf('SIMULINK_REANALYSIS_COMPLETE\n');
end
function y=cycleMean(signal,a,b,power)
take=signal.time>a & signal.time<b;t=[a;signal.time(take);b];
v=[interp1(signal.time,signal.data,a);signal.data(take);interp1(signal.time,signal.data,b)];
y=trapz(t,v.^power)/(b-a);
end
