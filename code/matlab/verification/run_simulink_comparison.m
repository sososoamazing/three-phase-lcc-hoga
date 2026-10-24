function run_simulink_comparison(refine)
% Strict frozen-Vo Simscape; initial states from independent ODE, never HOGA.
if nargin<1,refine=false;end
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'01_common'),fullfile(root,'02_HOGA','validated_model'),fullfile(root,'02_HOGA','legacy'));
cfg=model_config();maxNumCompThreads(1);model='lcc3_comparison';
addpath(fullfile(root,'05_verification','models'));
load_system(fullfile(root,'05_verification','models',[model '.slx']));
rows=struct([]);
for Vo=cfg.typical_voltages
    suffix='coarse';regR=1e-6;regG=1e-11;steps=250;cycles=32;
    if refine,suffix='fine';regR=1e-7;regG=1e-12;steps=500;cycles=64;end
    output=fullfile(root,'05_verification','data',sprintf('simulink_V%d_%s.mat',Vo,suffix));
    if isfile(output),d=load(output,'record');rows=[rows d.record];continue;end %#ok<AGROW>
    referenceData=load(fullfile(root,'00_audit','data','stage1_run02',sprintf('reference_V%d.mat',Vo)),'reference');
    x=referenceData.reference.periodic_initial_state;g=lcc3v2Geometry();
    ia=g.U*x(1:2);vc=g.U*x(3:4);vd=g.U*x(5:6)/cfg.n_sp;
    in=Simulink.SimulationInput(model);
    init=sprintf('SIMSTEP=1e-8;Vin=%.17g;Cs=%.17g;Ls=%.17g;Cp=%.17g;fs=%.17g;Ron=%.17g;Rd=%.17g;Co=6.25e-6;td=0;Coss=0;n=%.17g;', ...
        cfg.Vin,cfg.Cs,cfg.Ls,cfg.Cp_delta,cfg.fs,regR,regR,cfg.n_sp);
    in=in.setVariable('Vo_test',Vo);
    in=in.setModelParameter('InitFcn',init,'StopTime',num2str(cycles/cfg.fs,17), ...
        'Solver','ode15s','SolverType','Variable-step','MaxStep',num2str(1/(steps*cfg.fs),17), ...
        'RelTol','2e-7','AbsTol','2e-9','ZeroCrossAlgorithm','Adaptive', ...
        'SignalLogging','on','SignalLoggingName','logsout','ReturnWorkspaceOutputs','on', ...
        'LimitDataPoints','off','SimscapeLogType','none');
    for k=1:3
        in=blockParams(in,model,279+k,'r',num2str(regR,17),'g',num2str(regG,17), ...
            'i_L_specify','on','i_L_priority','High','i_L',num2str(ia(k),17));
        sid=[286 287 288];in=blockParams(in,model,sid(k),'r',num2str(regR,17),'g','0', ...
            'vc_specify','on','vc_priority','High','vc',num2str(vc(k),17));
        sid=[289 292 293];in=blockParams(in,model,sid(k),'r',num2str(regR,17),'g','0', ...
            'vc_specify','on','vc_priority','High','vc',num2str(vd(k),17));
    end
    in=blockParams(in,model,270,'R',num2str(cfg.Rin,17));
    for sid=273:278
        in=blockParams(in,model,sid,'Vf',num2str(cfg.Vf_rect,17),'Ron',num2str(regR,17),'Goff',num2str(regG,17));
    end
    for sid=254:259
        in=blockParams(in,model,sid,'Rds',num2str(regR,17),'Goff',num2str(regG,17), ...
            'diode_param','ee.enum.semiconductors.protectionDiode.nodynamics');
    end
    fprintf('SIM_START Vo=%g %s\n',Vo,suffix);timer=tic;
    try
        rawfile=strrep(output,'.mat','_raw.mat');
        if isfile(rawfile)
            raw=load(rawfile,'trace','elapsed');trace=raw.trace;elapsed=raw.elapsed;
        else
            out=sim(in);elapsed=toc(timer);trace=struct();names=out.logsout.getElementNames;
            for k=1:numel(names)
                values=out.logsout.get(names{k}).Values;
                trace.(names{k})=struct('time',values.Time,'data',values.Data);
            end
            save(rawfile,'trace','elapsed','in','cfg','-v7');
        end
        N=cfg.samples;tau=(0:N-1)'/N;t=(cycles-1+tau)/cfg.fs;
        waveform=struct('tau',tau,'i_A',zeros(N,3),'vDelta_V',zeros(N,3));
        iPrevious=zeros(N,3);
        for k=1:3
            name={'ia_A','ib_A','ic_A'};signal=trace.(name{k});
            waveform.i_A(:,k)=interp1(signal.time,signal.data,t,'linear');
            iPrevious(:,k)=interp1(signal.time,signal.data,t-1/cfg.fs,'linear');
            signal=trace.(sprintf('vDelta%d_V',k));waveform.vDelta_V(:,k)=interp1(signal.time,signal.data,t,'linear');
        end
        signal=trace.Io_A;waveform.iRect_A=interp1(signal.time,signal.data,t,'linear');
        signal=trace.Vo_V;voltage=interp1(signal.time,signal.data,t,'linear');
        record=struct('Vo',Vo,'fs',cfg.fs,'Io',mean(waveform.iRect_A),'Po',mean(voltage.*waveform.iRect_A), ...
            'Irms',sqrt(mean(waveform.i_A.^2,1)),'Ipeak',max(abs(waveform.i_A),[],1), ...
            'periodic_relative',norm(waveform.i_A-iPrevious,'fro')/norm(waveform.i_A,'fro'), ...
            'Vo_error_V',max(abs(voltage-Vo)),'solve_time',elapsed,'Rnum',regR,'Gnum',regG,'status','PASS');
        if record.periodic_relative>1e-3 || record.Vo_error_V>1e-6,record.status='NOT_CONVERGED';end
        save(output,'record','waveform','trace','cfg','in','-v7');
        rows=[rows record]; %#ok<AGROW>
        writetable(struct2table(rows,AsArray=true),fullfile(root,'05_verification','data',['simulink_' suffix '.csv']));
        fprintf('SIM_END Vo=%g Io=%g periodic=%g elapsed=%g\n',Vo,record.Io,record.periodic_relative,elapsed);
    catch err
        failure=getReport(err,'extended','hyperlinks','off');
        save(strrep(output,'.mat','_failed.mat'),'failure','in','cfg');fprintf('%s\n',failure);
    end
end
close_system(model,0);fprintf('SIMULINK_COMPARISON_COMPLETE\n');
end
function in=blockParams(in,model,sid,varargin)
block=Simulink.ID.getFullName(sprintf('%s:%d',model,sid));
for k=1:2:numel(varargin),in=in.setBlockParameter(block,varargin{k},varargin{k+1});end
end
