function result = lcc3v2Reference(p,Vo,settings)
%lcc3v2Reference Independent six-diode event integration and periodic shooting.
% No HOGA input is accepted. Diode currents are instantaneous KKT reactions.
arguments
    p (1,1) struct
    Vo (1,1) double {mustBePositive,mustBeFinite}
    settings.RelTol (1,1) double {mustBePositive} = 1e-9
    settings.AbsTol (1,1) double {mustBePositive} = 1e-10
    settings.MaxStep_T (1,1) double {mustBePositive} = 1/192
    settings.SettlePeriods (1,1) double {mustBeInteger,mustBeNonnegative} = 12
    settings.Samples (1,1) double {mustBeInteger,mustBePositive} = 8192
end
lcc3v2CheckParams(p);
g = lcc3v2Geometry();
Vd = Vo+2*p.Vf_rect;
beta = p.Cp_delta/p.n_sp^2;
scale = [p.Vin/sqrt(p.Ls/p.Cs)*ones(2,1);p.Vin*ones(2,1);Vd*ones(2,1)];
% A direct gate-map open circuit solves a DIFFERENT numerical problem from HB.
open = openCandidate();
openTrace = integrate(open,true);
if openTrace.maxViolation < p.event_voltage_tol && openTrace.allBlocked && ...
        norm((openTrace.endState-open)./scale,inf) < p.reference_tol
    chosen = open;
    history = struct('flag',1,'closure',norm((openTrace.endState-open)./scale,inf), ...
        'message','Feasible open periodic DC family; minimum-norm representative.');
else
    % Settle from zero only to seed this reference's shooting map.
    xstart = zeros(6,1);
    for k = 1:settings.SettlePeriods
        tr = integrate(xstart,false);
        xstart = tr.endState;
    end
    guesses = [xstart,zeros(6,1)];
    options = optimoptions('fsolve','Display','off','FunctionTolerance',1e-14, ...
        'OptimalityTolerance',1e-12,'StepTolerance',1e-12,'MaxIterations',100,'MaxFunctionEvaluations',1000);
    chosen = [];
    best = inf;
    history = struct('flag',{},'closure',{},'message',{});
    for k = 1:size(guesses,2)
        try
            [z,rr,flag,out] = fsolve(@shoot,guesses(:,k)./scale,options);
            closure = norm(rr,inf);
            history(end+1) = struct('flag',flag,'closure',closure,'message',out.message); %#ok<AGROW>
            if closure < best
                chosen = z.*scale;
                best = closure;
            end
            if closure < p.reference_tol
                break
            end
        catch err
            history(end+1) = struct('flag',-99,'closure',inf,'message',getReport(err)); %#ok<AGROW>
        end
    end
    if isempty(chosen)
        error('LCC3V2:ReferenceNoRoot','No finite independently shot periodic candidate.');
    end
end
trace = integrate(chosen,true);
tau = ((0:settings.Samples-1)'+0.371)/settings.Samples;
x = zeros(numel(tau),6);
j = zeros(numel(tau),2);
dx = zeros(size(x));
for k = 1:numel(trace.segments)
    seg = trace.segments(k);
    take = tau >= seg.a & tau < seg.b;
    y = deval(seg.sol,tau(take));
    x(take,:) = (y(1:6,:).*scale).';
    j(take,:) = (seg.D*x(take,1:2).').';
    dx(take,:) = (seg.M*x(take,:).' + seg.bvec).';
end
result = lcc3v2Metrics(p,Vo,tau,x,j,dx);
result.version = p.version;
result.method = 'independent adaptive event ODE + six-diode active-set KKT + periodic shooting';
result.params = p;
result.settings = settings;
result.Vo_V = Vo;
result.periodic_initial_state = chosen;
result.periodic_final_state = trace.endState;
result.closure_scaled = norm((trace.endState-chosen)./scale,inf);
energy = @(z) 0.5*sum([p.Ls;p.Ls;p.Cs;p.Cs;beta;beta].*z.^2);
result.metric.energy_one_period_J = energy(trace.endState)-energy(chosen);
result.metric.integrated_Pin_W = trace.integrals(1)*p.fs;
result.metric.integrated_bridge_W = trace.integrals(2)*p.fs;
result.metric.integrated_PRin_W = trace.integrals(3)*p.fs;
result.metric.integrated_power_residual_W = p.fs*sum(trace.integrals.*[1;-1;-1]);
result.metric.integration_energy_balance_J = sum(trace.integrals.*[1;-1;-1])-result.metric.energy_one_period_J;
result.metric.uniform_grid_Irect_mean_A = result.metric.Irect_mean_A;
result.metric.uniform_grid_power_residual_W = result.metric.power_residual_W;
result.metric.Irect_mean_A = trace.integrals(2)*p.fs/Vd;
result.metric.Pin_W = trace.integrals(1)*p.fs;
result.metric.PRin_W = trace.integrals(3)*p.fs;
result.metric.Pout_W = Vo*result.metric.Irect_mean_A;
result.metric.Pdiode_W = 2*p.Vf_rect*result.metric.Irect_mean_A;
result.metric.power_residual_W = result.metric.integrated_power_residual_W;
result.metric.power_relative_residual = abs(result.metric.power_residual_W)/max(1e-6,abs(result.metric.Pin_W));
result.events = trace.events;
result.segments = rmfield(trace.segments,'sol');
result.solver_history = history;
result.converged_periodic = result.closure_scaled < p.reference_tol;
result.physical_guard_pass = result.converged_periodic && ...
    result.metric.diode_voltage_violation_max_V < 10*p.event_voltage_tol && ...
    result.metric.active_diode_gap_max_V < 10*p.event_voltage_tol && ...
    abs(result.metric.integrated_power_residual_W) < 1e-5*max(1,abs(result.metric.integrated_Pin_W));
result.status = 'FAIL';
if ~result.converged_periodic
    result.status = 'NOT CONVERGED';
elseif result.physical_guard_pass
    result.status = 'PASS';
end
result.branch = 'conducting_periodic_candidate';
if trace.allBlocked
    result.branch = 'all_blocked_nonunique_DC_family';
end
result.branch_uniqueness_status = 'NOT RUN: no global uniqueness claim; no Floquet/stability study';

    function r = shoot(z)
        initial = z.*scale;
        tr = integrate(initial,false);
        r = (tr.endState-initial)./scale;
    end

    function tr = integrate(initial,keep)
        tr = struct('endState',initial,'integrals',zeros(3,1), ...
            'segments',struct('a',{},'b',{},'active',{},'M',{},'bvec',{},'D',{},'sol',{}), ...
            'events',struct('tau',{},'kind',{},'before',{},'after',{},'indices',{}, ...
                'transversality',{},'ambiguous',{}),'maxViolation',0,'allBlocked',true);
        initialE = initial(5:6);
        % A projected initial state is allowed ONLY in the shooting map. The
        % residual compares against the unprojected initial state, so a root
        % cannot conceal an infeasible initial voltage.
        if max(g.A*initialE) > Vd
            initial(5:6) = clampInitial(initialE);
        end
        state = [initial./scale;zeros(3,1)];
        cursor = 0;
        eventCount = 0;
        for gateIndex = 1:6
            finish = gateIndex/6;
            drive = (g.U'*lcc3v2Gate((gateIndex-0.5)/6).').';
            while cursor < finish-1e-13
                physical = state(1:6).*scale;
                f = p.n_sp/(3*p.Cp_delta)*g.C'*physical(1:2);
                di = (p.Vin*drive.'-p.Rin*(drive.'*drive)*physical(1:2) ...
                    -physical(3:4)-g.C*physical(5:6)/(3*p.n_sp))/p.Ls;
                % One-sided limiting mode at lambda=0 uses its derivative.
                probeF = f+p.n_sp/(3*p.Cp_delta)*g.C'*di*(1e-8/p.fs);
                mode = lcc3v2Mode(physical(5:6),probeF,Vd,beta, ...
                    p.event_voltage_tol,p.event_current_tol);
                [M,bvec,D] = circuit(mode.T,drive.');
                active = mode.active;
                inactive = setdiff(1:6,active);
                Aactive = g.A(active,:);
                if isempty(active)
                    lambdaMap = zeros(0,2);
                else
                    lambdaMap = (Aactive*Aactive')\Aactive*g.C'/(3*p.n_sp);
                end
                begin = cursor;
                opts = odeset('RelTol',settings.RelTol,'AbsTol',settings.AbsTol, ...
                    'MaxStep',settings.MaxStep_T,'Events',@modeEvents);
                sol = ode45(@rhs,[begin finish],state,opts);
                cursor = sol.x(end);
                state = sol.y(:,end);
                eventCount = eventCount+1;
                if eventCount > 160 || cursor <= begin+1e-14
                    error('LCC3V2:EventChatter','Non-transverse/simultaneous event unresolved at tau=%g.',cursor);
                end
                tr.allBlocked = tr.allBlocked && isempty(active);
                tr.maxViolation = max(tr.maxViolation,max(g.A*(sol.y(5:6,:).*scale(5:6))-Vd,[],'all'));
                if keep
                    tr.segments(end+1) = struct('a',begin,'b',cursor,'active',active, ...
                        'M',M,'bvec',bvec,'D',D,'sol',sol); %#ok<AGROW>
                end
                if isfield(sol,'ie') && ~isempty(sol.ie)
                    at = state(1:6).*scale;
                    rates = M*at+bvec;
                    indices = sol.ie(sol.xe >= cursor-1e-9);
                    eventRates = [-g.A(inactive,:)*rates(5:6);lambdaMap*rates(1:2)]/p.fs;
                    afterF = p.n_sp/(3*p.Cp_delta)*g.C'*(at(1:2)+rates(1:2)*(1e-8/p.fs));
                    after = lcc3v2Mode(at(5:6),afterF,Vd,beta,p.event_voltage_tol,p.event_current_tol);
                    if keep
                        tr.events(end+1) = struct('tau',cursor,'kind','diode', ...
                            'before',active,'after',after.active,'indices',indices, ...
                            'transversality',eventRates(indices), ...
                            'ambiguous',after.ambiguous || numel(indices)>1); %#ok<AGROW>
                    end
                end
            end
            if keep && gateIndex < 6
                tr.events(end+1) = struct('tau',cursor,'kind','gate', ...
                    'before',active,'after',[],'indices',[],'transversality',[], ...
                    'ambiguous',false); %#ok<AGROW>
            end
        end
        tr.endState = state(1:6).*scale;
        tr.integrals = state(7:9);

        function dy = rhs(~,y)
            xp = y(1:6).*scale;
            rate = M*xp+bvec;
            secCurrent = D*xp(1:2);
            ec = g.U*xp(5:6);
            jc = g.U*secCurrent;
            id = drive*xp(1:2);
            dy = [rate./scale; p.Vin*id; sum(ec.*jc); p.Rin*id^2]/p.fs;
        end
        function [values,terminal,direction] = modeEvents(t,y)
            xp = y(1:6).*scale;
            values = [Vd-g.A(inactive,:)*xp(5:6);lambdaMap*xp(1:2)];
            if t <= begin+1e-12
                values = max(values,1e-11);
            end
            terminal = ones(size(values));
            direction = -ones(size(values));
        end
    end

    function x0 = openCandidate()
        transition = eye(7);
        for s = 1:6
            q = g.U'*lcc3v2Gate((s-0.5)/6).';
            [M,bvec] = circuit(eye(2),q);
            transition = expm([M bvec;zeros(1,7)]/(6*p.fs))*transition;
        end
        lhs = (transition(1:6,1:6)-eye(6)).*scale.'./scale;
        rhs = -transition(1:6,7)./scale;
        x0 = scale.*lsqminnorm(lhs,rhs,1e-12);
    end

    function [M,bvec,D] = circuit(T,q)
        M = [-p.Rin*(q*q')/p.Ls, -eye(2)/p.Ls, -g.C/(3*p.n_sp*p.Ls); ...
            eye(2)/p.Cs, zeros(2), zeros(2); ...
            T*p.n_sp*g.C'/(3*p.Cp_delta),zeros(2),zeros(2)];
        bvec = [p.Vin*q/p.Ls;zeros(4,1)];
        D = (eye(2)-T)*g.C'/(3*p.n_sp);
    end

    function e = clampInitial(e)
        % Exhaustive closest feasible edge point; no time-step projection.
        nodes = [2 -1 -1;1 1 -2;-1 2 -1;-2 1 1;-1 -1 2;1 -2 1]*Vd/3*g.U;
        bestDistance = inf;
        for s = 1:6
            a = nodes(s,:).';
            ab = nodes(mod(s,6)+1,:).'-a;
            candidate = a+min(1,max(0,ab'*(e-a)/(ab'*ab)))*ab;
            distance = norm(candidate-e);
            if distance < bestDistance
                closest = candidate;
                bestDistance = distance;
            end
        end
        e = closest;
    end
end
