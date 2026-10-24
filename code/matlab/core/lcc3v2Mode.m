function m = lcc3v2Mode(e,freeRate,Vd,beta,voltageTol,currentTol)
%lcc3v2Mode Solve the tangent-cone KKT system by enumerating touching faces.
% This is a local circuit law, not a trajectory integrator or diode schedule.
arguments
    e (2,1) double {mustBeFinite}
    freeRate (2,1) double {mustBeFinite}
    Vd (1,1) double {mustBePositive,mustBeFinite}
    beta (1,1) double {mustBePositive,mustBeFinite}
    voltageTol (1,1) double {mustBeNonnegative,mustBeFinite} = 2e-7
    currentTol (1,1) double {mustBeNonnegative,mustBeFinite} = 1e-10
end
g = lcc3v2Geometry();
slack = Vd - g.A*e;
if min(slack) < -10*voltageTol
    error('LCC3V2:InfeasibleState','Secondary voltage is outside the diode hexagon by %g V.',-min(slack));
end
touch = find(slack <= voltageTol);
sets = {zeros(1,0)};
for k = 1:numel(touch)
    sets{end+1} = touch(k); %#ok<AGROW>
end
for k = 1:numel(touch)
    for l = k+1:numel(touch)
        sets{end+1} = touch([k l]).'; %#ok<AGROW>
    end
end
valid = struct('active',{},'T',{},'lambda',{},'j',{},'rate',{});
rateTol = max(1e-6, currentTol/beta);
for k = 1:numel(sets)
    active = sets{k};
    A = g.A(active,:);
    if isempty(active)
        T = eye(2);
        lambda = zeros(0,1);
    else
        if rcond(A*A') < 1e-12
            continue
        end
        lambda = beta*((A*A')\(A*freeRate));
        T = eye(2) - A'*((A*A')\A);
    end
    rate = T*freeRate;
    if all(lambda >= -currentTol) && all(g.A(touch,:)*rate <= rateTol)
        valid(end+1) = struct('active',active,'T',T,'lambda',lambda, ...
            'j',beta*(freeRate-rate),'rate',rate); %#ok<AGROW>
    end
end
if isempty(valid)
    error('LCC3V2:ModeUnresolved','No diode mode satisfies the local KKT inequalities.');
end
m = valid(1);
m.ambiguous = numel(valid) > 1;
m.touching = touch;
m.slack = slack;
end
