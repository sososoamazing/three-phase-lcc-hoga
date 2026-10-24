function probeSwitchingPoint(Vo,fn,k,seedVo,seedStage)
% Independent switch-model probe: does a conducting periodic orbit exist at this
% operating point at all? No HOGA reference is used except as a starting state,
% and the starting state is scaled from a different (accepted) voltage.
% Saves runtime/probe_<tag>.mat and prints current, stress and periodicity.
if nargin<4,seedVo=Vo;end
if nargin<5,seedStage='B';end
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'core'),fullfile(root,'legacy'),fullfile(root,'scripts'),fullfile(root,'models'));
maxNumCompThreads(1);cd(fullfile(root,'runtime'));
model='lcc3_ideal_charge';
open_system(fullfile(root,'models',[model '.slx']));
p=lcc3v2Params('original_reduced');fr=1/(2*pi*sqrt(p.Ls*p.Cs));
p.fs=fn*fr;p.Cp_delta=k*p.Cs;
g=lcc3v2Geometry();
seedFile=fullfile(root,'data',seedStage,sprintf('V%07.2f_F%06.3f_K%06.3f.mat',seedVo,fn,k));
if ~isfile(seedFile)
    for st={'B','A','C'}
        cand=fullfile(root,'data',st{1},sprintf('V%07.2f_F%06.3f_K%06.3f.mat',seedVo,fn,k));
        if isfile(cand),seedFile=cand;break;end
    end
end
d=load(seedFile,'record','solution');
fprintf('PROBE seed %s accepted=%d\n',seedFile,d.record.accepted);
x=lcc3v2Evaluate(d.solution,0);
x=x*(Vo+2*p.Vf_rect)/(seedVo+2*p.Vf_rect);
ia=x(1:2)*g.U';vc=x(3:4)*g.U';vd=x(5:6)*g.U'/p.n_sp;
regR=1e-6;regG=1e-11;cycles=64;dt=1/(p.fs*250);
init=sprintf(['SIMSTEP=1e-8;Vin=50;Cs=135e-9;Ls=4.7e-6;Cp=%.17g;fs=%.17g;' ...
    'Ron=1e-6;Rd=1e-6;Co=.0625;td=0;Coss=0;n=4;'],p.Cp_delta,p.fs);
in=Simulink.SimulationInput(model);
in=in.setModelParameter('InitFcn',init,'StopTime',num2str(cycles/p.fs,17), ...
    'Solver','ode15s','SolverType','Variable-step','MaxStep',num2str(dt,17), ...
    'RelTol','2e-7','AbsTol','2e-9','ZeroCrossAlgorithm','Adaptive', ...
    'SignalLogging','on','SignalLoggingName','logsout','ReturnWorkspaceOutputs','on', ...
    'LimitDataPoints','off','SimscapeLogType','none');
for sid=280:282
    path=Simulink.ID.getFullName(sprintf('%s:%d',model,sid));
    in=blockParams(in,path,'r',num2str(regR,17),'g',num2str(regG,17), ...
        'i_L_specify','on','i_L_priority','High','i_L',num2str(ia(sid-279),17));
end
for j=1:3
    sids=[286 287 288];path=Simulink.ID.getFullName(sprintf('%s:%d',model,sids(j)));
    in=blockParams(in,path,'r',num2str(regR,17),'vc_specify','on','vc_priority','High','vc',num2str(vc(j),17));
    sids=[289 292 293];path=Simulink.ID.getFullName(sprintf('%s:%d',model,sids(j)));
    in=blockParams(in,path,'r',num2str(regR,17),'vc_specify','on','vc_priority','High','vc',num2str(vd(j),17));
end
for sid=[279 294]
    path=Simulink.ID.getFullName(sprintf('%s:%d',model,sid));
    in=blockParams(in,path,'r',num2str(regR,17),'vc_specify','on','vc_priority','High','vc',num2str(Vo/2,17));
end
in=in.setBlockParameter(Simulink.ID.getFullName([model ':270']),'R','.001');
for sid=273:278
    path=Simulink.ID.getFullName(sprintf('%s:%d',model,sid));
    in=blockParams(in,path,'Vf','.6','Ron',num2str(regR,17),'Goff',num2str(regG,17));
end
for sid=254:259
    path=Simulink.ID.getFullName(sprintf('%s:%d',model,sid));
    in=blockParams(in,path,'Rds',num2str(regR,17),'Goff',num2str(regG,17), ...
        'diode_param','ee.enum.semiconductors.protectionDiode.nodynamics');
end
fprintf('PROBE_START V=%g fn=%.3f k=%.3g\n',Vo,fn,k);timer=tic;
out=sim(in);elapsed=toc(timer);
names=out.logsout.getElementNames;trace=struct();
for j=1:numel(names)
    values=out.logsout.get(names{j}).Values;
    trace.(names{j})=struct('time',values.Time,'data',values.Data);
end
t0=(cycles-8)/p.fs;t1=cycles/p.fs;t=linspace(t0,t1,8*2048+1).';
curr=zeros(numel(t),3);names3={'ia_A','ib_A','ic_A'};
for j=1:3,curr(:,j)=interp1(trace.(names3{j}).time,trace.(names3{j}).data,t,'linear');end
io=interp1(trace.Io_A.time,trace.Io_A.data,t,'linear');
vo=interp1(trace.Vo_V.time,trace.Vo_V.data,t,'linear');
Io=trapz(t,io)/(t1-t0);rms=sqrt(trapz(t,curr.^2,1)/(t1-t0));peak=max(abs(curr),[],1);
a=curr(end-2048+1:end,:);b=curr(end-4096+1:end-2048,:);
periodic=100*norm(a-b,'fro')/max(norm(a,'fro'),1e-12);
drift=100*(max(vo)-min(vo))/max(mean(vo),1);
% first-cycle current, to see whether conduction decays towards zero
tA=(0:2048)/p.fs;cA=interp1(trace.ia_A.time,trace.ia_A.data,tA,'linear');
fprintf('PROBE_END V=%g fn=%.3f k=%.3g Io=%.4f Im=%.4f Irms=%.4f periodic=%.3f%% drift=%.4g%% first_cycle_peak=%.3f t=%.1fs\n', ...
    Vo,fn,k,Io,max(peak),max(rms),periodic,drift,max(abs(cA)),elapsed);
save(fullfile(root,'runtime',sprintf('probe_V%g_F%.2f_K%g.mat',Vo,fn,k)),'trace','Io','peak','rms','periodic','drift','elapsed');
close_system(model,0);
end

function in=blockParams(in,path,varargin)
for j=1:2:numel(varargin),in=in.setBlockParameter(path,varargin{j},varargin{j+1});end
end
