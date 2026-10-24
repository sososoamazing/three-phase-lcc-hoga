function probe=studyOpenOrbit(p,Vo)
% Independent exact open-circuit gate map; explicitly fix the free mean e=0.
% A minimum-norm initial state alone need not select the zero-DC representative.
g=lcc3v2Geometry();Vd=Vo+2*p.Vf_rect;
scale=[p.Vin/sqrt(p.Ls/p.Cs)*ones(2,1);p.Vin*ones(2,1);Vd*ones(2,1)];
S=diag([scale;1;Vd;Vd]);transition=eye(9);maps=cell(6,1);
for segment=1:6
    q=g.U'*lcc3v2Gate((segment-.5)/6).';
    M=[-p.Rin*(q*q')/p.Ls,-eye(2)/p.Ls,-g.C/(3*p.n_sp*p.Ls); ...
        eye(2)/p.Cs,zeros(2),zeros(2);p.n_sp*g.C'/(3*p.Cp_delta),zeros(2),zeros(2)];
    A=zeros(9);A(1:6,1:6)=M;A(1:6,7)=[p.Vin*q/p.Ls;zeros(4,1)];
    A(8:9,5:6)=p.fs*eye(2);maps{segment}=S\A*S;
    transition=expm(maps{segment}/(6*p.fs))*transition;
end
lhs=[transition(1:6,1:6)-eye(6);transition(8:9,1:6)];
rhs=-transition([1:6 8:9],7);z0=lhs\rhs;
state=[z0;1;0;0];peak=0;
for segment=1:6
    for fraction=linspace(0,1,129)
        at=S*(expm(maps{segment}*fraction/(6*p.fs))*state);
        peak=max(peak,max(g.A*at(5:6)));
    end
    state=expm(maps{segment}/(6*p.fs))*state;
end
probe=struct('initial_state',scale.*z0,'closure',norm(state(1:6)-z0,inf), ...
    'mean_e_alpha_beta_V',Vd*state(8:9),'open_span_peak_V',peak, ...
    'method','independent scaled affine open gate map with zero secondary DC mean');
end
