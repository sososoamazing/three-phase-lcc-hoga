function result = solve_three_phase_lcc_reference(params,Vo,Nsteps)
% INDEPENDENT periodic switched-complementarity reference (NOT FFT fit).
% Projected-midpoint time stepping of the exact 6D physical ODE/DAE.
% A cone projection enforces ideal diode unilateral constraints every step.
% Periodic initial state is solved via stroboscopic map fsolve; no HOGA
% coefficients, diode intervals, waveforms or initial states are used.
% Nsteps: multiple of 6; redo at 2*Nsteps to quantify integration error.
if nargin<1 || isempty(params),params=lcc3_default_params();end
if nargin<3 || isempty(Nsteps),Nsteps=params.reference_steps;end
validateattributes(Vo,{'numeric'},{'scalar','finite','positive'});
validateattributes(Nsteps,{'numeric'},{'integer','scalar','>=',600});
assert(mod(Nsteps,6)==0,'Reference steps must be multiple of 6 to resolve all bridge edges.');
[U,~,C]=lcc3_physics('basis');
Vd=Vo+2*params.Vf_rect;n=params.n_sp;
Iscale=params.Vin/sqrt(params.Ls/params.Cs);
Vscale=max(params.Vin,Vd/n);
sc=[Iscale;Iscale;params.Vin;params.Vin;Vscale;Vscale];
% Initial guesses are independent physical guesses, not an HOGA orbit.
guesses=[zeros(6,1), [0;0;0;0;Vd/5;0]./sc, ...
 [0;0;0;0;0;Vd/5]./sc,[Iscale;0;0;0;0;0]./sc];
opt=optimoptions('fsolve','Display','off','FunctionTolerance',params.reference_tol, ...
 'StepTolerance',1e-11,'MaxIterations',100,'MaxFunctionEvaluations',1500);
solves=struct('flag',{},'closure',{},'message',{});
chosen=[]; best=inf;
for trial=1:size(guesses,2)
 try
  [z,rr,flag,output]=fsolve(@period_residual,guesses(:,trial),opt);
  er=norm(rr,inf);
  solves(end+1)=struct('flag',flag,'closure',er,'message',output.message); %#ok<AGROW>
  if all(isfinite(z)) && er<best,chosen=z;best=er;end
  if flag>0 && er<params.reference_tol,break;end
 catch ME
  solves(end+1)=struct('flag',-99,'closure',Inf,'message',ME.message); %#ok<AGROW>
 end
end
if isempty(chosen)
 error('LCC3:ReferenceNoRoot','Switched time-domain reference found no finite candidate.');
end
[xend,tr]=integrate_one(chosen.*sc,true);
x0=chosen.*sc;
% The reference samples are independent switching ODE time-step values.
t=tr.tau(1:end-1);i2=tr.x(1:end-1,1:2);
vs2=tr.x(1:end-1,3:4);e2=tr.x(1:end-1,5:6);
i=i2*U';vs=vs2*U';e=e2*U';j=tr.j2*U';
Irect=.5*sum(abs(j),2);
d=lcc3_physics('gate',t+0.5/Nsteps);
idc=sum(d.*((tr.x(1:end-1,1:2)+tr.x(2:end,1:2))/2*U'),2);
% Midpoint primary current in idc avoids one-sided quadrature near edges.
Pin=params.Vin*mean(idc);Pout=Vo*mean(Irect);
Pd=2*params.Vf_rect*mean(Irect);Pr=params.Rin*mean(idc.^2);
E=@(x) .5*params.Ls*sum(x(1:2).^2)+ ...
 .5*params.Cs*sum(x(3:4).^2)+ ...
 .5*params.Cp_delta/n^2*sum(x(5:6).^2);
range=max(e,[],2)-min(e,[],2);
eEnd=tr.x(2:end,5:6)*U';
pass=abs(sum(eEnd.*j,2)-Vd*Irect);
result=struct();result.method='independent time-stepped projected ideal-diode DAE';
result.Vo_V=Vo;result.Nsteps=Nsteps;result.params=params;
result.periodic_initial_state=x0;result.periodic_final_state=xend;
result.closure_scaled=norm((xend-x0)./sc,inf);
result.converged_periodic=best<params.reference_tol;
result.solver_history=solves;result.t_over_T=t;
result.t_s=t/params.fs;
result.wave=struct('i_A',i,'vCs_V',vs,'vDelta_V',e/n, ...
 'vSec_V',e,'jSecondary_A',j,'iRect_A',Irect,'iDC_A',idc, ...
 'dUpper',d,'active_diode_count',sum(j>1e-7,2)+sum(j<(-1e-7),2));
result.events=lcc3_extract_intervals(t,j);
result.metric=struct('Irect_mean_A',mean(Irect), ...
 'Irect_rms_A',sqrt(mean(Irect.^2)), ...
 'iLine_rms_A',sqrt(mean(i.^2,1)), ...
 'iLine_peak_A',max(abs(i),[],1), ...
 'vDelta_peak_V',max(abs(e/n),[],1), ...
 'vCs_peak_V',max(abs(vs),[],1), ...
 'jSec_rms_A',sqrt(mean(j.^2,1)),'jSec_peak_A',max(abs(j),[],1), ...
 'Pin_W',Pin,'Pout_W',Pout,'Pdiode_W',Pd,'PRin_W',Pr, ...
 'power_residual_W',Pin-Pout-Pd-Pr, ...
 'power_relative_residual',abs(Pin-Pout-Pd-Pr)/max(1,abs(Pin)), ...
 'energy_one_period_J',E(xend)-E(x0), ...
 'diode_voltage_violation_max_V',max(0,max(range-Vd)), ...
 'passivity_residual_max_W',max(pass), ...
 'active_diode_voltage_event_max_V',active_clamp_error(max(eEnd,[],2)-min(eEnd,[],2),Irect,Vd), ...
 'sum_i_max_A',max(abs(sum(i,2))), ...
 'sum_j_max_A',max(abs(sum(j,2))), ...
 'conduction_fraction_grid',mean(Irect>1e-7));
result.status='SWITCHED_REFERENCE_NUMERICAL_CANDIDATE: refine time step and compare';
if ~result.converged_periodic
 result.status='NOT_CONVERGED_PERIODIC: candidate not certified';
end

 function r=period_residual(z)
  xx=z.*sc; xe=integrate_one(xx,false);
  r=(xe-xx)./sc;
 end
 function [xe,trace]=integrate_one(x,keep)
  dt=1/(params.fs*Nsteps);
  if keep
   trace=struct('tau',(0:Nsteps)'/Nsteps,'x',zeros(Nsteps+1,6), ...
    'j2',zeros(Nsteps,2));trace.x(1,:)=x.';
  else
   trace=[];
  end
  for k=1:Nsteps
   t0=(k-1)/Nsteps;tm=(k-.5)/Nsteps;
   [di,dvs,de]=free_rhs(x,t0);
   xm=x+[di;dvs;de]*dt/2;
   xm(5:6)=lcc3_physics('project',xm(5:6).',Vd,U).';
   [di2,dvs2,de2]=free_rhs(xm,tm);
   xf=x+[di2;dvs2;de2]*dt;
   ep=lcc3_physics('project',xf(5:6).',Vd,U).';
   if keep
    % Current follows the discrete secondary capacitor charge correction.
    jp=(params.Cp_delta/n^2)*(xf(5:6)-ep)/dt;
    trace.j2(k,:)=jp.';
   end
   x=[xf(1:4);ep];
   if keep,trace.x(k+1,:)=x.';end
  end
  xe=x;
 end
 function [di,dvs,de]=free_rhs(x,t)
  d=lcc3_physics('gate',t);p=U'*d';
  di=(params.Vin*p-params.Rin*p*(p.'*x(1:2))- ...
       x(3:4)-C*x(5:6)/(3*n))/params.Ls;
  dvs=x(1:2)/params.Cs;
  de=n/(3*params.Cp_delta)*C.'*x(1:2);
 end
end

function err=active_clamp_error(span,ir,V)
active=ir>1e-5;
if any(active),err=max(abs(span(active)-V));else,err=0;end
end
