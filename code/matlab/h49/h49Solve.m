function result = h49Solve(p,Vo,seed)
%h49Solve Event-enriched moving-Fourier equilibrium, FIXED to H = 49.
%
% This file is a controlled derivative of the audited vectorised kernel
% 02_HOGA/accelerated/studyHoga.m (itself equivalence-checked against
% 02_HOGA/validated_model/lcc3v2Hoga.m by validate_acceleration.m).
%
% Differences from studyHoga.m, and nothing else:
%   (D1) The harmonic order is fixed at H = 49. The argument is removed so a
%        caller cannot accidentally obtain another order from this model.
%   (D2) The legacy "min(H,7)" topology-discovery solve is removed. A prior
%        HOGA event solution is mandatory; this campaign always seeds from the
%        archived H31 solution at the SAME (Vo,fs) operating point. The seed
%        supplies an event topology and an initial guess only - never a result.
%   (D3) The all-blocked branch hands the prior HOGA open-branch coefficients
%        to the legacy open-rectifier solver at H = 49 as an initial guess.
%   (D4) Extra diagnostics are recorded (conjugate symmetry, spectral residual,
%        index bookkeeping). No equation, guard, tolerance or parameter changes.
%
% Retained Fourier indices: h = -49..-1, +1..+49 (98 complex coefficients per
% alpha/beta coordinate). The DC current coefficient is not an unknown: the
% series-capacitor periodicity constraint gives i_0 = 0 exactly, so the model
% covers 99 harmonic indices (98 solved + 1 identically zero), not 99 unknowns.
%
% No switching reference coefficients, events or waveforms are accepted.
% Verified H49 equations only: no fitting, no relaxed guard, no parameter edit.
arguments
    p (1,1) struct
    Vo (1,1) double {mustBeNonnegative,mustBeFinite}
    seed (1,1) struct
end
H = 49;
lcc3v2CheckParams(p);
if isempty(fieldnames(seed)) || ~isfield(seed,'event_schedule') || ...
        ~isfield(seed,'method') || ~contains(seed.method,'Fourier')
    error('H49:BadSeed','H49 requires a prior HOGA event solution; no other order is solved.');
end
if ~isfield(seed,'Vo_V') || seed.Vo_V ~= Vo
    error('H49:BadSeed','Event continuation requires a previous HOGA result at the same Vo.');
end
g = lcc3v2Geometry();
Vd = Vo+2*p.Vf_rect;
assert(Vd>0,'H49:DegenerateClamp','Vo+2Vf must be positive.');
omega = 2*pi*p.fs;
h = [-H:-1 1:H];
Nh = numel(h);
assert(Nh==2*H,'H49:IndexBookkeeping','Expected 2H nonzero Fourier indices.');
Kf = p.n_sp*g.C'/(3*p.Cp_delta);
[~,Pz,Qz] = lcc3_physics('fourier_drive',H,g.U);
assert(size(Pz,2)==4*H+1 && size(Qz,3)==4*H+1, ...
    'H49:ConvolutionRange','Gate product spectrum must cover +/-2H.');
schedule = seed.event_schedule;
initialE = seed.e_initial_alpha_beta;
diodeEdges = schedule.edges(2:end-1);
modeSets = schedule.active;
if isempty(diodeEdges) && isempty(modeSets{1})
    result = allBlockedResult();
    return
end
Ne = numel(diodeEdges);
% Bounds preserve the proposed topology. A failed/collapsed topology remains
% failed and is never silently assigned a different conducting mode.
gateEdges = (0:6)/6;
lower = zeros(1,Ne);
upper = ones(1,Ne);
for eventIndex = 1:Ne
    left = max(gateEdges(gateEdges < diodeEdges(eventIndex)));
    right = min(gateEdges(gateEdges > diodeEdges(eventIndex)));
    if eventIndex > 1
        left = max(left,(diodeEdges(eventIndex-1)+diodeEdges(eventIndex))/2);
    end
    if eventIndex < Ne
        right = min(right,(diodeEdges(eventIndex)+diodeEdges(eventIndex+1))/2);
    end
    lower(eventIndex) = left+1e-10;
    upper(eventIndex) = right-1e-10;
end
initial = [initialE/Vd;diodeEdges.'];
% Iteration limits are numerical settings only. Defaults reproduce the audited
% behaviour exactly; a recovery run may raise them, which never relaxes a guard.
maxIterations = 100; maxFunctionEvaluations = 1500;
if isfield(p,'solverMaxIterations') && ~isempty(p.solverMaxIterations)
    maxIterations = p.solverMaxIterations;
end
if isfield(p,'solverMaxFunctionEvaluations') && ~isempty(p.solverMaxFunctionEvaluations)
    maxFunctionEvaluations = p.solverMaxFunctionEvaluations;
end
options = optimoptions('lsqnonlin','Display','off','FunctionTolerance',1e-15, ...
    'StepTolerance',1e-12,'OptimalityTolerance',1e-12,'MaxIterations',maxIterations, ...
    'MaxFunctionEvaluations',maxFunctionEvaluations);
[variables,~,rr,flag,out,~,jacobian] = lsqnonlin(@eventResidual,initial, ...
    [-2;-2;lower.'],[2;2;upper.'],options);
[Ic,Ec,vs0,edges,modes,deltaE] = coefficients(variables);
e0 = variables(1:2)*Vd;
N = max(8192,64*(2*H+1));
tau = ((0:N-1)'+0.371)/N;
[x,j,dx] = reconstruct(tau,Ic,vs0,e0,edges,modes);
result = lcc3v2Metrics(p,Vo,tau,x,j,dx);
result.metric.uniform_grid_Irect_mean_A = result.metric.Irect_mean_A;
result.metric.uniform_grid_power_residual_W = result.metric.power_residual_W;
integrals = exactIntegrals(Ic,vs0,edges,modes);
result.metric.Irect_mean_A = integrals.Irect;
result.metric.Irect_rms_A = integrals.IrectRms;
result.metric.Pin_W = integrals.Pin;
result.metric.Pout_W = Vo*integrals.Irect;
result.metric.Pdiode_W = 2*p.Vf_rect*integrals.Irect;
result.metric.PRin_W = integrals.PRin;
result.metric.power_residual_W = integrals.Pin-Vd*integrals.Irect-integrals.PRin;
result.metric.power_relative_residual = abs(result.metric.power_residual_W)/max(1e-6,abs(integrals.Pin));
result.metric.iLine_rms_A = integrals.iLineRms;
result.metric.jSec_rms_A = integrals.jSecRms;
result.metric.iPrimary_rms_A = p.n_sp*integrals.jSecRms;
result.method = 'event-enriched moving-Fourier equilibrium / mode-integral Fourier-Galerkin HOGA (fixed H=49)';
result.version = p.version;
result.params = p;
result.Vo_V = Vo;
result.H = H;
result.h = (-H:H).';
result.coeff = struct('i_alpha_beta',[Ic(:,1:H) zeros(2,1) Ic(:,H+1:end)], ...
    'e_alpha_beta',Ec,'vCs_alpha_beta',voltageCoefficients(Ic,vs0));
result.e_initial_alpha_beta = e0;
result.event_schedule = schedule;
result.event_schedule.edges = [0 variables(3:end).' 1];
result.event_schedule.topology_verified = false;
result.event_schedule.raw_mode_ids = [];
result.events = eventReport(Ic,vs0,e0,edges,modes,variables(3:end));
result.solver_history = struct('exitflag',flag,'message',out.message, ...
    'iterations',out.iterations,'event_residual_scaled',norm(rr,inf), ...
    'jacobian_singular_values',svd(full(jacobian)));
result.converged_algebraic = norm(rr,inf) < p.hoga_tol;
result.metric.event_equation_residual_V = norm(rr,inf)*Vd;
result.metric.period_end_voltage_error_V = norm(deltaE,inf);
result.metric.fourier_kvl_residual_V = spectralResidual(Ic,Ec,vs0);
result.metric.kvl_rms_V = sqrt(mean(sum((p.Ls*dx(:,1:2)-p.Vin*lcc3v2Gate(tau)*g.U ...
    +p.Rin*result.wave.iDC_A.*(lcc3v2Gate(tau)*g.U)+x(:,3:4)+x(:,5:6)*g.C'/(3*p.n_sp)).^2,2)));
energyWeights = [p.Ls;p.Ls;p.Cs;p.Cs;p.Cp_delta/p.n_sp^2;p.Cp_delta/p.n_sp^2];
ends = reconstruct([0;1],Ic,vs0,e0,edges,modes);
result.periodic_initial_state = ends(1,:).';
result.periodic_final_state = ends(2,:).';
result.metric.energy_one_period_J = 0.5*sum(energyWeights.*(ends(2,:).^2-ends(1,:).^2).');
result.closure_scaled = max(abs((ends(2,:)-ends(1,:))./[p.Vin/sqrt(p.Ls/p.Cs)*ones(1,2) p.Vin*ones(1,2) Vd*ones(1,2)]));
result.metric.min_diode_current_signed_A = minModeCurrent(Ic,edges,modes);
result.physical_guard_pass = result.converged_algebraic && ...
    result.metric.diode_voltage_violation_max_V <= p.physical_voltage_rel*Vd && ...
    result.metric.normal_max_V <= p.physical_voltage_rel*Vd && ...
    result.metric.min_diode_current_signed_A >= -1e-7 && ...
    result.metric.power_relative_residual <= p.physical_power_rel && ...
    ~any([result.events.ambiguous]);
result.branch = 'conducting_two_diode_intervals';
if any(cellfun(@numel,modeSets)>1)
    result.branch = 'conducting_with_three_diode_intervals';
elseif any(cellfun(@isempty,modeSets))
    result.branch = 'conducting_with_all_blocked_intervals';
end
result.status = 'FAIL';
if ~result.converged_algebraic
    result.status = 'NOT CONVERGED';
elseif result.physical_guard_pass
    result.status = 'PASS';
    result.event_schedule.topology_verified = true;
end
result.pointwise_kvl_status = 'FAIL: finite Fourier current cannot uniformly reproduce gate derivative jumps';
result.acceptance_scope = 'PASS applies to configured diode/weak-KVL/energy guards only; no order/ref convergence is claimed for H49';
% D4: H49 bookkeeping and conjugate-symmetry diagnostics.
conjResidual = max(abs(result.coeff.i_alpha_beta(:,[1:H H+2:2*H+1])- ...
    conj(fliplr(result.coeff.i_alpha_beta(:,[1:H H+2:2*H+1])))),[],'all');
result.diagnostics = struct('H',H,'nonzero_indices',Nh,'total_indices',2*H+1, ...
    'dc_current_fixed_A',0,'dc_current_rule','series-capacitor periodicity i_0=0 (not an unknown)', ...
    'gate_product_max_order',2*H,'conjugate_symmetry_max_abs',conjResidual, ...
    'spectral_kvl_residual_V',result.metric.fourier_kvl_residual_V, ...
    'closure_scaled',result.closure_scaled,'seed_source',seed.method);
result.seed_vo_V = seed.Vo_V;
result.seed_method = seed.method;

    function residual = eventResidual(v)
        if isfield(p,'researchTimer') && toc(p.researchTimer)>p.maxPointSeconds
            error('Study:Timeout','Numerical time budget reached; point remains unresolved.');
        end
        [I,~,~,ed,ms,de] = coefficients(v);
        eStart = v(1:2)*Vd;
        voltages = secondaryAt(ed,I,eStart,ed,ms);
        residual = de/Vd;
        % All active constraints at interval starts. Redundant equations are
        % retained and handled by least squares; no arbitrary DC constraint.
        for s = 1:numel(ms)
            active = ms{s};
            residual = [residual;(g.A(active,:)*voltages(s,:).'-Vd)/Vd]; %#ok<AGROW>
        end
        % Every dropped face must either end at a voltage event (another face
        % arrives) or have zero reaction for release into the interior.
        for s = 2:numel(ms)
            before = ms{s-1};
            after = ms{s};
            if isequal(before,after) || any(abs(ed(s)-gateEdges)<1e-9)
                continue
            end
            removed = setdiff(before,after);
            added = setdiff(after,before);
            if isempty(added) && ~isempty(removed)
                A = g.A(before,:);
                line = real(I*exp(1i*2*pi*h.'*ed(s)));
                lambda = (A*A')\A*g.C'*line/(3*p.n_sp);
                residual = [residual;lambda(ismember(before,removed))/max(1,p.Vin/sqrt(p.Ls/p.Cs))]; %#ok<AGROW>
            end
        end
    end

    function [I,E,vc0,ed,ms,de] = coefficients(v)
        ev = v(3:end).';
        ed = unique(sort([0 ev gateEdges 1]));
        ms = cell(1,numel(ed)-1);
        for s = 1:numel(ms)
            index = find([0 ev] <= (ed(s)+ed(s+1))/2,1,'last');
            ms{s} = modeSets{index};
        end
        derivativeMap = complex(zeros(2,2,2*H+1,Nh));
        momentMap = complex(zeros(2,2,Nh));
        cfIndex = (-H:H).'-h+2*H+1;
        for s = 1:numel(ms)
            A = g.A(ms{s},:);T = eye(2);
            if ~isempty(A),T = T-A'*((A*A')\A);end
            TK = T*Kf;
            cf = intervalCoef((-2*H:2*H).',ed(s),ed(s+1));
            derivativeMap = derivativeMap + reshape(TK,2,2,1,1).*reshape(cf(cfIndex),1,1,2*H+1,Nh);
            momentMap = momentMap + reshape(TK,2,2,1).*reshape(momentCoef(h,ed(s),ed(s+1)),1,1,Nh)/p.fs;
        end
        emap = (derivativeMap(:,:,h+H+1,:)-derivativeMap(:,:,H+1,:))./reshape(1i*h*omega,1,1,Nh,1);
        qIndex = h.'-h+2*H+1;
        qBlocks = reshape(Qz(:,:,qIndex(:)),2,2,Nh,Nh);
        blocks = p.Rin*qBlocks+pagemtimes(g.C,emap)/(3*p.n_sp);
        linear = reshape(permute(blocks,[1 3 2 4]),2*Nh,2*Nh);
        diagonal = 1i*h*omega*p.Ls+1./(1i*h*omega*p.Cs);
        linear = linear+diag(repelem(diagonal,2));
        force = reshape(p.Vin*Pz(:,h+2*H+1),2*Nh,1);
        if rcond(linear) < 1e-13
            error('H49:SingularHoga','Event-conditioned current block is singular at H=49.');
        end
        I = reshape(linear\force,2,Nh);
        momentTerms = pagemtimes(momentMap,reshape(I,2,1,Nh));
        E = complex(zeros(2,2*H+1));
        E(:,H+1) = real(v(1:2)*Vd+reshape(sum(momentTerms,3),2,1));
        dcTerms = pagemtimes(reshape(derivativeMap(:,:,H+1,:),2,2,Nh),reshape(I,2,1,Nh));
        de = real(reshape(sum(dcTerms,3),2,1)/p.fs);
        eTerms = pagemtimes(emap,reshape(I,2,1,1,Nh));
        E(:,h+H+1) = reshape(sum(eTerms,4),2,Nh);
        dropTerms = pagemtimes(Qz(:,:,-h+2*H+1),reshape(I,2,1,Nh));
        dcDrop = reshape(sum(dropTerms,3),2,1);
        vc0 = real(p.Vin*Pz(:,2*H+1)-p.Rin*dcDrop-g.C*E(:,H+1)/(3*p.n_sp));
    end

    function e = secondaryAt(t,I,eStart,ed,ms)
        e = repmat(eStart.',numel(t),1);
        for s = 1:numel(ms)
            A = g.A(ms{s},:);
            T = eye(2);
            if ~isempty(A)
                T = T-A'*((A*A')\A);
            end
            take = t >= ed(s);
            upperBound = min(t(take),ed(s+1));
            integrals = (exp(1i*2*pi*upperBound(:)*h)-exp(1i*2*pi*ed(s)*h))./(1i*2*pi*h*p.fs);
            e(take,:) = e(take,:)+real(integrals*I.'*Kf'*T');
        end
    end

    function [x,j,dx] = reconstruct(t,I,vc0,eStart,ed,ms)
        F = exp(1i*2*pi*t(:)*h);
        iq = real(F*I.');
        vsq = real(F*(I./(1i*omega*h*p.Cs)).')+vc0.';
        eq = secondaryAt(t,I,eStart,ed,ms);
        x = [iq vsq eq];
        j = zeros(numel(t),2);
        dx = [real(F*(I.*(1i*omega*h)).') iq/p.Cs zeros(numel(t),2)];
        for s = 1:numel(ms)
            take = t >= ed(s) & (t < ed(s+1) | (s==numel(ms) & t <= ed(s+1)));
            A = g.A(ms{s},:);
            T = eye(2);
            if ~isempty(A)
                T = T-A'*((A*A')\A);
            end
            dx(take,5:6) = iq(take,:)*Kf'*T';
            j(take,:) = iq(take,:)*g.C*(eye(2)-T)/(3*p.n_sp);
        end
    end

    function V = voltageCoefficients(I,dc)
        V = complex(zeros(2,2*H+1));
        V(:,H+1) = dc;
        V(:,[1:H H+2:2*H+1]) = I./(1i*omega*h*p.Cs);
    end

    function residual = spectralResidual(I,E,dc)
        V = voltageCoefficients(I,dc);
        allI = [I(:,1:H) zeros(2,1) I(:,H+1:end)];
        residual = 0;
        for m = 1:2*H+1
            hm = m-H-1;
            drop = zeros(2,1);
            for k = 1:2*H+1
                drop = drop+Qz(:,:,hm-(k-H-1)+2*H+1)*allI(:,k);
            end
            r = 1i*hm*omega*p.Ls*allI(:,m)+V(:,m)+g.C*E(:,m)/(3*p.n_sp) ...
                +p.Rin*drop-p.Vin*Pz(:,hm+2*H+1);
            residual = max(residual,norm(r,inf));
        end
    end

    function minimum = minModeCurrent(I,ed,ms)
        minimum = 0;
        for s = 1:numel(ms)
            A = g.A(ms{s},:);
            if isempty(A)
                continue
            end
            grid = linspace(ed(s),ed(s+1),max(32,8*H)).';
            iq = real(exp(1i*2*pi*grid*h)*I.');
            lambda = iq*g.C*A'/(3*p.n_sp)/(A*A');
            minimum = min(minimum,min(lambda,[],'all'));
        end
    end

    function values = exactIntegrals(I,~,ed,ms)
        values = struct('Irect',0,'IrectRms',0,'Pin',0,'PRin',0, ...
            'iLineRms',sqrt(sum(abs(g.U*I).^2,2)).','jSecRms',zeros(1,3));
        jSquare = zeros(1,3);
        irSquare = 0;
        for s = 1:numel(ms)
            A = g.A(ms{s},:);
            T = eye(2);
            if ~isempty(A)
                T = T-A'*((A*A')\A);
            end
            D = (eye(2)-T)*g.C'/(3*p.n_sp);
            jCoef = g.U*D*I;
            positives = unique(g.pairs(ms{s},1));
            irCoef = sum(jCoef(positives,:),1);
            q = g.U'*lcc3v2Gate((ed(s)+ed(s+1))/2).';
            idCoef = q'*I;
            area = intervalCoef(-h.',ed(s),ed(s+1));
            pairArea = reshape(intervalCoef(-(h.'+h),ed(s),ed(s+1)),Nh,Nh);
            values.Irect = values.Irect+real(irCoef*area);
            values.Pin = values.Pin+p.Vin*real(idCoef*area);
            values.PRin = values.PRin+p.Rin*real(idCoef*pairArea*idCoef.');
            irSquare = irSquare+real(irCoef*pairArea*irCoef.');
            jSquare = jSquare+real(diag(jCoef*pairArea*jCoef.')).';
        end
        values.IrectRms = sqrt(max(0,irSquare));
        values.jSecRms = sqrt(max(0,jSquare));
    end

    function events = eventReport(I,vc0,eStart,ed,ms,eventTimes)
        events = struct('tau',{},'kind',{},'before',{},'after',{},'transversality',{},'ambiguous',{});
        for k = 1:numel(eventTimes)
            at = eventTimes(k);
            index = find(ed==at,1); % exact identity in constructed edges
            before = ms{index-1};
            after = ms{index};
            added = setdiff(after,before);
            removed = setdiff(before,after);
            [~,~,dstate] = reconstruct(at-1e-11,I,vc0,eStart,ed,ms);
            rate = g.A(added,:)*dstate(5:6).'/p.fs;
            if isempty(added) && ~isempty(removed)
                A = g.A(before,:);
                lambdaRate = (A*A')\A*g.C'*dstate(1:2).'/(3*p.n_sp*p.fs);
                rate = lambdaRate(ismember(before,removed));
            end
            events(k) = struct('tau',at,'kind','diode','before',before,'after',after, ...
                'transversality',rate,'ambiguous',numel(added)>1 || isempty(rate) || ...
                any(abs(rate)<1e-7) || any(abs(at-gateEdges)<1e-8));
        end
    end

    function blocked = allBlockedResult()
        % Retain the independently solved open spectral candidate and classify
        % its two secondary DC freedoms and the common Cs bias separately.
        % D3: the prior HOGA open solution is an initial guess only (same H49
        % equations); it never supplies a result, event set or waveform.
        legacySeed = [];
        if isfield(seed,'coeff') && isfield(seed,'h') && isfield(seed.coeff,'e_alpha_beta')
            legacySeed = struct('h',seed.h,'coeff',struct('e_alpha_beta',seed.coeff.e_alpha_beta));
        end
        discovery = solve_three_phase_lcc_hoga(p,Vo,H,legacySeed);
        blocked = discovery;
        grid = ((0:8191)'+0.371)/8192;
        F = exp(1i*2*pi*grid*discovery.h.');
        xp = real(F*[discovery.coeff.i_alpha_beta.' discovery.coeff.vCs_alpha_beta.' discovery.coeff.e_alpha_beta.']);
        jp = real(F*discovery.coeff.j_alpha_beta.');
        dp = real(F*((1i*omega*discovery.h).*[discovery.coeff.i_alpha_beta.' discovery.coeff.vCs_alpha_beta.' discovery.coeff.e_alpha_beta.']));
        diagnostics = lcc3v2Metrics(p,Vo,grid,xp,jp,dp);
        blocked.metric = diagnostics.metric;
        blocked.wave = diagnostics.wave;
        blocked.t_over_T = diagnostics.t_over_T;
        blocked.t_s = diagnostics.t_s;
        blocked.events = struct('tau',{},'kind',{},'before',{},'after',{},'transversality',{},'ambiguous',{});
        blocked.metric.kvl_rms_V = NaN;
        blocked.metric.fourier_kvl_residual_V = 0;
        blocked.metric.event_equation_residual_V = 0;
        blocked.metric.energy_one_period_J = 0;
        blocked.metric.period_end_voltage_error_V = 0;
        blocked.version = p.version;
        blocked.H = H;
        blocked.branch = 'all_blocked_nonunique_DC_family';
        blocked.event_schedule = schedule;
        blocked.e_initial_alpha_beta = g.U'*discovery.wave.vSec_V(1,:).';
        blocked.nullspace_dimension = 2;
        blocked.common_Cs_bias = 'arbitrary conserved scalar; representative set to zero';
        blocked.periodic_initial_state = xp(1,:).';
        blocked.periodic_final_state = xp(1,:).';
        blocked.closure_scaled = 0;
        blocked.pointwise_kvl_status = 'FAIL: gate derivative jumps; periodic Fourier closure is a representation identity';
        blocked.status = 'PASS';
        if ~discovery.physical_guard_pass
            blocked.status = 'FAIL';
        end
        blocked.diagnostics = struct('H',H,'nonzero_indices',Nh,'total_indices',2*H+1, ...
            'dc_current_fixed_A',0,'dc_current_rule','all-blocked family: i_0=0 by periodicity', ...
            'gate_product_max_order',2*H,'conjugate_symmetry_max_abs',NaN, ...
            'spectral_kvl_residual_V',0,'closure_scaled',0,'seed_source',seed.method);
        blocked.seed_vo_V = seed.Vo_V;
        blocked.seed_method = seed.method;
        blocked = lcc3v2FinalizeOpen(blocked);
    end
end

function c = intervalCoef(h,a,b)
width = b-a;
x = pi*h*width;
s = ones(size(x));
take = abs(x)>0;
s(take) = sin(x(take))./x(take);
c = width*s.*exp(-1i*pi*h*(a+b));
end

function c = momentCoef(h,a,b)
w = 1i*2*pi*h;
if h == 0
    c = (b-a)-(b^2-a^2)/2;
else
    c = exp(w*b).*((1-b)./w+1./w.^2)-exp(w*a).*((1-a)./w+1./w.^2);
end
end
