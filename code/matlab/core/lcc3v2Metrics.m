function result = lcc3v2Metrics(p,Vo,tau,x,j2,dx)
%lcc3v2Metrics Independent dimensional circuit, diode and energy diagnostics.
arguments
    p (1,1) struct
    Vo (1,1) double {mustBePositive,mustBeFinite}
    tau (:,1) double {mustBeFinite}
    x (:,6) double {mustBeFinite}
    j2 (:,2) double {mustBeFinite}
    dx (:,6) double = zeros(0,6)
end
g = lcc3v2Geometry();
Vd = Vo + 2*p.Vf_rect;
i = x(:,1:2)*g.U';
vs = x(:,3:4)*g.U';
e = x(:,5:6)*g.U';
j = j2*g.U';
d = lcc3v2Gate(tau);
idc = sum(d.*i,2);
upper = max(j,0);
lower = max(-j,0);
ir = sum(upper,2);
lo = -p.Vf_rect - min(e,[],2);
hi = Vo + p.Vf_rect - max(e,[],2);
neutral = (lo+hi)/2;
gapU = Vo+p.Vf_rect - e-neutral;
gapL = e+neutral+p.Vf_rect;
active = [upper lower] > 1e-7;
gaps = [gapU gapL];
activeGap = gaps;
activeGap(~active) = 0;
weight = repmat([p.Ls p.Ls p.Cs p.Cs p.Cp_delta/p.n_sp^2 p.Cp_delta/p.n_sp^2],size(x,1),1);
energy = 0.5*sum(weight.*x.^2,2);
pin = p.Vin*idc;
pr = p.Rin*idc.^2;
portResidual = sum(e.*j,2) - Vd*ir;
normal = zeros(size(j2));
% Projection is independently derived from the six geometric edges here.
for k = 1:size(x,1)
    normal(k,:) = x(k,5:6) - projectHex(x(k,5:6)+p.project_sigma_ohm*j2(k,:),Vd,g);
end
metric = struct('Irect_mean_A',mean(ir),'Irect_rms_A',sqrt(mean(ir.^2)), ...
    'iLine_rms_A',sqrt(mean(i.^2,1)),'iLine_peak_A',max(abs(i),[],1), ...
    'jSec_rms_A',sqrt(mean(j.^2,1)),'jSec_peak_A',max(abs(j),[],1), ...
    'iPrimary_rms_A',p.n_sp*sqrt(mean(j.^2,1)), ...
    'iPrimary_peak_A',p.n_sp*max(abs(j),[],1), ...
    'vCs_peak_V',max(abs(vs),[],1),'vDelta_peak_V',max(abs(e/p.n_sp),[],1), ...
    'Pin_W',mean(pin),'Pout_W',Vo*mean(ir),'Pdiode_W',2*p.Vf_rect*mean(ir), ...
    'PRin_W',mean(pr),'power_residual_W',mean(pin-pr-Vd*ir), ...
    'power_relative_residual',abs(mean(pin-pr-Vd*ir))/max(abs(mean(pin)),1e-6), ...
    'diode_voltage_violation_max_V',max(0,-min(gaps,[],'all')), ...
    'active_diode_gap_max_V',max(abs(activeGap),[],'all'), ...
    'normal_max_V',max(vecnorm(normal,2,2)), ...
    'normal_rms_V',sqrt(mean(sum(normal.^2,2))), ...
    'diode_product_max_W',max(abs([upper lower].*gaps),[],'all'), ...
    'rectifier_power_identity_max_W',max(abs(portResidual)), ...
    'sum_i_max_A',max(abs(sum(i,2))),'sum_j_max_A',max(abs(sum(j,2))), ...
    'all_blocked_fraction',mean(~any(active,2)), ...
    'three_or_more_diode_fraction',mean(sum(active,2)>=3), ...
    'energy_range_J',max(energy)-min(energy), ...
    'kvl_max_V',NaN,'capacitor_kcl_max_A',NaN,'instant_energy_identity_max_W',NaN);
if ~isempty(dx)
    iq = x(:,1:2);
    eq = x(:,5:6);
    pq = d*g.U;
    kvl = p.Ls*dx(:,1:2) - p.Vin*pq + p.Rin*idc.*pq + x(:,3:4) + eq*g.C'/(3*p.n_sp);
    kcl = p.Cp_delta/p.n_sp^2*dx(:,5:6) - iq*g.C/(3*p.n_sp) + j2;
    cs = p.Cs*dx(:,3:4) - iq;
    energyRate = sum(weight.*x.*dx,2);
    metric.kvl_max_V = max(abs(kvl),[],'all');
    metric.capacitor_kcl_max_A = max(abs([kcl cs]),[],'all');
    metric.instant_energy_identity_max_W = max(abs(energyRate-pin+pr+sum(e.*j,2)));
end
wave = struct('i_A',i,'vCs_V',vs,'vDelta_V',e/p.n_sp,'vSec_V',e, ...
    'jSecondary_A',j,'iPrimary_A',p.n_sp*j,'iCpDelta_A',zeros(size(j)), ...
    'iRect_A',ir,'iDC_A',idc,'dUpper',d,'diodeUpper_A',upper, ...
    'diodeLower_A',lower,'neutral_V',neutral,'neutral_feasible_interval_V',[lo hi], ...
    'diodeGaps_V',gaps,'active_diode_count',sum(active,2),'energy_J',energy);
if ~isempty(dx)
    wave.iCpDelta_A = p.Cp_delta/p.n_sp*(dx(:,5:6)*g.U');
end
result = struct('metric',metric,'wave',wave,'t_over_T',tau,'t_s',tau/p.fs);
end

function z = projectHex(y,V,g)
if max(g.A*y.') <= V
    z = y;
    return
end
vertices = [2 -1 -1;1 1 -2;-1 2 -1;-2 1 1;-1 -1 2;1 -2 1]*V/3*g.U;
best = inf;
z = y;
for k = 1:6
    a = vertices(k,:);
    b = vertices(mod(k,6)+1,:);
    ab = b-a;
    q = a + min(1,max(0,(y-a)*ab'/(ab*ab')))*ab;
    cost = sum((q-y).^2);
    if cost < best
        best = cost;
        z = q;
    end
end
end
