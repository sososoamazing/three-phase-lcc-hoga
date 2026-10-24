function result = solve_three_phase_lcc_hoga(params,Vo,H,seed)
% Three-LEG Delta/Y LCC, fixed-Vo periodic Fourier/Galerkin HOGA.
% H is maximum SIGNED harmonic: h=-H,...,0,...,H (all integers).
% Requires Optimization Toolbox (fsolve). No waveform from reference solver
% enters the HOGA equations or initialization.
if nargin<1 || isempty(params),params=lcc3_default_params();end
if nargin<4,seed=[];end
validateattributes(Vo,{'numeric'},{'scalar','real','finite','positive'});
validateattributes(H,{'numeric'},{'scalar','integer','positive'});
assert(params.Ls>0 && params.Cs>0 && params.Cp_delta>0 && ...
 params.n_sp>0 && params.fs>0 && params.Vin>0 && params.Rin>=0);
[U,B,C]=lcc3_physics('basis'); n=params.n_sp;
ws=2*pi*params.fs; h=(-H:H).'; Nh=numel(h); Nv=2*Nh;
[z,Pz,Qz]=lcc3_physics('fourier_drive',H,U);
% Harmonic KVL with common Rin: convolution by p(t)p(t)^T, p=U'*d.
% i_0=0 follows from Cs*dvCs/dt=i; capacitor DC voltages are recovered.
A=complex(zeros(Nv)); f=complex(zeros(Nv,1)); K=complex(zeros(Nv));
for m=1:Nh
 row=2*m-1:2*m; hm=h(m);
 if hm==0, A(row,row)=eye(2);continue;end
 f(row)=params.Vin*Pz(:,hm+2*H+1);
 K(row,row)=-C/(3*n);
 A(row,row)=A(row,row)+(1i*hm*ws*params.Ls+ ...
                            1/(1i*hm*ws*params.Cs))*eye(2);
 for k=1:Nh
  col=2*k-1:2*k;
  A(row,col)=A(row,col)+params.Rin*Qz(:,:,hm-h(k)+2*H+1);
 end
end
if rcond(A)<1e-13
 error('LCC3:SingularSpectralLinear','Spectral current matrix near singular; investigate fs and truncation.');
end
ibase=A\f; imap=A\K;
Jbase=complex(zeros(Nv,1)); Jmap=complex(zeros(Nv));
for m=1:Nh
 row=2*m-1:2*m;
 Jbase(row)=(C.'/(3*n))*ibase(row);
 Jmap(row,:)=(C.'/(3*n))*imap(row,:);
 Jmap(row,row)=Jmap(row,row)-params.Cp_delta/n^2*(1i*h(m)*ws)*eye(2);
end
Nq=max(params.Nfourier, 16*(2*H+1)); Nq=ceil(Nq/6)*6;
t=(0:Nq-1)'/Nq; F=exp(1i*2*pi*t*h.');
Vd=Vo+2*params.Vf_rect; sigma=params.project_sigma_ohm;
sc=max(params.Vin,Vd/n);
% Open-rectifier periodic spectral solution (j_h=0); its DC e is set to zero.
not0=find(h~=0); inds=reshape([2*not0-1,2*not0].',[],1);
eopen=complex(zeros(Nv,1));
if rcond(Jmap(inds,inds))>1e-13
 eopen(inds)=-(Jmap(inds,inds)\Jbase(inds));
end
eopen=force_real(eopen,h);
Eopen=reshape(eopen,2,Nh);
openE=real(F*Eopen.');
openExcess=max(max(openE*U',[],2)-min(openE*U',[],2)-Vd);
% HOGA initial guesses may use an algebraic OPEN-CIRCUIT spectral solution;
% never the independent switched reference trajectory.
start={};
if ~isempty(seed)
 start{end+1}=pack(seed_to_coeff(seed,h),H,sc); %#ok<AGROW>
end
if openExcess<=1e-8*max(1,Vd)
 starts={pack(Eopen,H,sc)};
else
 clipped=lcc3_physics('project',openE,Vd,U);
 Ec=(F'*clipped/Nq).';
 Ec=force_real(Ec(:),h); Ec=reshape(Ec,2,Nh);
 starts=[start,{pack(Ec,H,sc),pack(Eopen,H,sc),zeros(Nv,1)}];
end
opt=optimoptions('fsolve','Display','off','FunctionTolerance',params.hoga_tol, ...
 'StepTolerance',1e-11,'MaxIterations',200,'MaxFunctionEvaluations',12000);
solves=struct('exitflag',{},'spectral_normal_residual_V',{},'iterations',{},'message',{});
chosen=[]; score=inf;
for trial=1:numel(starts)
 try
  [xx,rr,flag,output]=fsolve(@project_residual,starts{trial},opt);
  rmax=norm(rr,inf)*sc;
  solves(end+1)=struct('exitflag',flag,'spectral_normal_residual_V',rmax, ...
        'iterations',output.iterations,'message',output.message); %#ok<AGROW>
  if rmax<score && all(isfinite(xx)),chosen=xx;score=rmax;end
  if flag>0 && rmax<=params.hoga_tol*sc,break;end
 catch ME
  solves(end+1)=struct('exitflag',-99,'spectral_normal_residual_V',Inf, ...
   'iterations',0,'message',ME.message); %#ok<AGROW>
 end
end
if isempty(chosen)
 error('LCC3:HogaNoRoot','No finite Fourier candidate found.');
end
Ec=unpack(chosen,H,sc); ee=Ec(:);
Ic=reshape(ibase+imap*ee,2,Nh);
Jc=reshape(Jbase+Jmap*ee,2,Nh);
Vc=complex(zeros(2,Nh));
for m=1:Nh
 if h(m)~=0
  Vc(:,m)=Ic(:,m)/(1i*h(m)*ws*params.Cs);
 else
  summ=complex(zeros(2,1));
  for k=1:Nh
   summ=summ+Qz(:,:,2*H+1-h(k))*Ic(:,k);
  end
  Vc(:,m)=params.Vin*Pz(:,2*H+1)-params.Rin*summ-C*Ec(:,m)/(3*n);
 end
end
wa=real(F*Ic.');wv=real(F*Vc.');we=real(F*Ec.');wj=real(F*Jc.');
i=wa*U';vCs=wv*U';e=we*U';j=wj*U';
Irect=.5*sum(abs(j),2);
d=lcc3_physics('gate',t); idc=sum(d.*i,2);
normal=we-lcc3_physics('project',we+sigma*wj,Vd,U);
range=max(e,[],2)-min(e,[],2);
perr=sum(e.*j,2)-Vd*Irect;
Pin=params.Vin*mean(idc); Pout=Vo*mean(Irect);
Pd=2*params.Vf_rect*mean(Irect); Pr=params.Rin*mean(idc.^2);
result=struct();
result.method='finite-H moving-Fourier equilibrium / Fourier-Galerkin rectifier normal cone';
result.model='true 3-leg Delta-Cp / Delta-Y transformer / 6-diode bridge';
result.Vo_V=Vo; result.H=H;result.h=h;result.params=params;
result.branch='unverified';
if max(Irect)<1e-7,result.branch='candidate_all_blocked_neutral_DC_family';
elseif mean(Irect)>0,result.branch='candidate_conducting';end
result.converged_algebraic=(score<=params.hoga_tol*sc);
result.solver_history=solves; result.scaling_V=sc;
result.coeff=struct('e_alpha_beta',Ec,'i_alpha_beta',Ic,'vCs_alpha_beta',Vc, ...
 'j_alpha_beta',Jc);
result.t_s=t/params.fs;result.t_over_T=t;
result.wave=struct('i_A',i,'vCs_V',vCs,'vDelta_V',e/n,'vSec_V',e, ...
 'jSecondary_A',j,'iRect_A',Irect,'iDC_A',idc, ...
 'dUpper',d,'active_diode_count',sum(j>1e-7,2)+sum(j<(-1e-7),2));
result.events=lcc3_extract_intervals(t,j);
result.metric=struct('Irect_mean_A',mean(Irect),'Irect_rms_A',sqrt(mean(Irect.^2)), ...
 'iLine_rms_A',sqrt(mean(i.^2,1)),'iLine_peak_A',max(abs(i),[],1), ...
 'vDelta_peak_V',max(abs(e/n),[],1), 'vCs_peak_V',max(abs(vCs),[],1), ...
 'jSec_rms_A',sqrt(mean(j.^2,1)), 'jSec_peak_A',max(abs(j),[],1), ...
 'Pin_W',Pin,'Pout_W',Pout,'Pdiode_W',Pd,'PRin_W',Pr, ...
 'power_residual_W',Pin-Pout-Pd-Pr, ...
 'power_relative_residual',abs(Pin-Pout-Pd-Pr)/max(1,abs(Pin)), ...
 'fourier_complementarity_residual_V',score, ...
 'pointwise_normal_residual_max_V',max(sqrt(sum(normal.^2,2))), ...
 'diode_voltage_violation_max_V',max(0,max(range-Vd)), ...
 'passivity_residual_max_W',max(abs(perr)), ...
 'sum_i_max_A',max(abs(sum(i,2))),'sum_j_max_A',max(abs(sum(j,2))), ...
 'sum_vDelta_max_V',max(abs(sum(e,2)/n)), ...
 'conduction_fraction_grid',mean(Irect>1e-7), ...
 'periodic_reconstruction_closure_max',0, ...
 'active_diode_voltage_event_max_V',active_clamp_error(range,Irect,Vd));
% 'periodic_reconstruction_closure_max' is identically zero by Fourier ansatz,
% not an independent physical orbit closure or feasibility certificate.
result.physical_guard_pass= result.converged_algebraic && ...
 result.metric.diode_voltage_violation_max_V<=1e-3*max(1,Vd) && ...
 result.metric.pointwise_normal_residual_max_V<=1e-3*max(1,Vd) && ...
 result.metric.power_relative_residual<=1e-3;
result.status='CANDIDATE_ONLY: R2024b execution, H convergence and independent reference required';
if result.physical_guard_pass
 result.status='PASSES_CONFIGURED_ALGEBRAIC_GUARDS_ONLY; needs H and reference comparisons';
end

 function rr=project_residual(x)
  E=unpack(x,H,sc); ev=E(:);
  J=reshape(Jbase+Jmap*ev,2,Nh);
  wt=real(F*E.');jt=real(F*J.');
  normal=wt-lcc3_physics('project',wt+sigma*jt,Vd,U);
  rc=(F'*normal/Nq).';
  rr=pack(rc,H,sc);
 end
end

function c=force_real(c,h)
c=reshape(c,2,numel(h));H=max(abs(h));
c(:,h==0)=real(c(:,h==0));
for k=1:H
 avg=(c(:,h==k)+conj(c(:,h==-k)))/2;
 c(:,h==k)=avg;c(:,h==-k)=conj(avg);
end
end
function v=pack(c,H,scale)
c=reshape(c,2,2*H+1);v=zeros(2*(2*H+1),1);
v(1:2)=real(c(:,H+1))/scale;
for k=1:H
 z=c(:,H+1+k);ii=2+(k-1)*4+(1:4);
 v(ii)=[real(z);imag(z)]/scale;
end
end
function c=unpack(v,H,scale)
c=complex(zeros(2,2*H+1));c(:,H+1)=scale*v(1:2);
for k=1:H
 ii=2+(k-1)*4+(1:4);z=scale*(v(ii(1:2))+1i*v(ii(3:4)));
 c(:,H+1+k)=z;c(:,H+1-k)=conj(z);
end
end
function c=seed_to_coeff(seed,h)
if ~isstruct(seed) || ~isfield(seed,'coeff') || ~isfield(seed,'h')
 error('LCC3:BadSeed','seed must be a previous HOGA result struct.');
end
c=complex(zeros(2,numel(h)));
for m=1:numel(h)
 idx=find(seed.h==h(m),1);
 if ~isempty(idx),c(:,m)=seed.coeff.e_alpha_beta(:,idx);end
end
end

function err=active_clamp_error(span,ir,V)
active=ir>1e-5;
if any(active),err=max(abs(span(active)-V));else,err=0;end
end
