function [x,j2] = lcc3v2Evaluate(sol,tau)
%lcc3v2Evaluate Reconstruct an HOGA result, including exact mode voltage integrals.
arguments
    sol (1,1) struct
    tau (:,1) double {mustBeFinite,mustBeNonnegative}
end
g = lcc3v2Geometry();
p = sol.params;
% Continue periodic states beyond one cycle. Preserve the original [0,1]
% endpoints so an independent closure check can still observe endpoint error.
later = tau > 1;
tau(later) = mod(tau(later),1);
h = sol.h.';
F = exp(1i*2*pi*tau*h);
i = real(F*sol.coeff.i_alpha_beta.');
v = real(F*sol.coeff.vCs_alpha_beta.');
if ~isfield(sol,'e_initial_alpha_beta') || ~contains(sol.method,'event-enriched')
    x = [i v real(F*sol.coeff.e_alpha_beta.')];
    j2 = real(F*sol.coeff.j_alpha_beta.');
    return
end
nonzero = h~=0;
hn = h(nonzero);
I = sol.coeff.i_alpha_beta(:,nonzero);
edges = sol.event_schedule.edges;
modes = sol.event_schedule.active;
e = repmat(sol.e_initial_alpha_beta.',numel(tau),1);
j2 = zeros(numel(tau),2);
Kf = p.n_sp*g.C'/(3*p.Cp_delta);
for s = 1:numel(modes)
    A = g.A(modes{s},:);
    T = eye(2);
    if ~isempty(A)
        T = T-A'*((A*A')\A);
    end
    take = tau >= edges(s);
    upper = min(tau(take),edges(s+1));
    integral = (exp(1i*2*pi*upper(:)*hn)-exp(1i*2*pi*edges(s)*hn))./(1i*2*pi*hn*p.fs);
    e(take,:) = e(take,:)+real(integral*I.'*Kf'*T');
    here = tau >= edges(s) & (tau < edges(s+1) | (s==numel(modes) & tau <= 1));
    j2(here,:) = i(here,:)*g.C*(eye(2)-T)/(3*p.n_sp);
end
x = [i v e];
end
