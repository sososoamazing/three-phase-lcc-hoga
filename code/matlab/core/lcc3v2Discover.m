function schedule = lcc3v2Discover(candidate,p,Vo,strategy)
%lcc3v2Discover Trial mode topology solely from an unverified HOGA candidate.
% The topology is a hypothesis. All subsequent inequalities must verify it.
arguments
    candidate (1,1) struct
    p (1,1) struct
    Vo (1,1) double {mustBePositive}
    strategy (1,1) string {mustBeMember(strategy,["faces","support","support_coalesced","release"])} = "faces"
end
if ~isfield(candidate,'coeff') || ~isfield(candidate,'H') || ...
        ~contains(candidate.method,'Fourier')
    error('LCC3V2:BadDiscovery','Mode discovery requires a HOGA spectral candidate.');
end
g = lcc3v2Geometry();
tau = candidate.t_over_T;
e = candidate.wave.vSec_V;
j = candidate.wave.jSecondary_A;
span = max(e,[],2)-min(e,[],2);
[~,hi] = max(e,[],2);
[~,lo] = min(e,[],2);
peak = max(vecnorm(j,2,2));
blocked = peak < 1e-7 | (vecnorm(j,2,2) < max(1e-7,0.08*peak) & span < 0.995*(Vo+2*p.Vf_rect));
mode = zeros(size(tau));
for k = 1:6
    mode(hi==g.pairs(k,1) & lo==g.pairs(k,2) & ~blocked) = 2^(k-1);
end
if strategy == "support" || strategy == "support_coalesced"
    Vd = Vo+2*p.Vf_rect;
    highSupport = j > 0.14*peak & e >= max(e,[],2)-0.15*Vd;
    lowSupport = j < -0.14*peak & e <= min(e,[],2)+0.15*Vd;
    for index = 1:numel(tau)
        uppers = find(highSupport(index,:));
        lowers = find(lowSupport(index,:));
        if numel(uppers)+numel(lowers) >= 3 && ~isempty(uppers) && ~isempty(lowers)
            pairs = find(ismember(g.pairs(:,1),uppers) & ismember(g.pairs(:,2),lowers));
            mode(index) = sum(2.^(pairs-1));
        end
    end
end
rawSupportModes = mode;
if strategy == "support_coalesced"
    % A second HOGA-only topology hypothesis: a flat corner may acquire
    % alternating max/min face labels from Fourier truncation. Extend a
    % discovered vertex through the last return to its incoming face, up to
    % the next distinct vertex. This is NOT evidence that those events are
    % fictitious: only a physically verified event solve can accept the trial.
    vertices = find(arrayfun(@(value)sum(bitget(uint32(value),1:6))==2,mode));
    cursor = 1;
    while cursor <= numel(vertices)
        index = vertices(cursor);
        vertex = mode(index);
        previous = find(mode(1:index-1)~=vertex,1,'last');
        nextDifferent = find(arrayfun(@(value)sum(bitget(uint32(value),1:6))==2 && value~=vertex, ...
            mode(index+1:end)),1);
        limit = numel(mode);
        if ~isempty(nextDifferent)
            limit = index+nextDifferent-1;
        end
        if ~isempty(previous)
            incoming = mode(previous);
            incomingBits = bitget(uint32(incoming),1:6);
            vertexBits = bitget(uint32(vertex),1:6);
            if sum(incomingBits)==1 && all(incomingBits <= vertexBits)
                lastReturn = find(mode(index:limit)==incoming,1,'last');
                if ~isempty(lastReturn)
                    mode(index:index+lastReturn-1) = vertex;
                end
            end
        end
        cursor = find(vertices > limit,1);
        if isempty(cursor)
            break
        end
    end
end
if strategy == "release"
    if ~isfield(candidate,'event_schedule')
        error('LCC3V2:BadReleaseSeed','A release hypothesis requires an event HOGA candidate.');
    end
    mode(:) = 0;
    for s = 1:numel(candidate.event_schedule.active)
        active = candidate.event_schedule.active{s};
        take = tau >= candidate.event_schedule.edges(s) & tau < candidate.event_schedule.edges(s+1);
        mode(take) = sum(2.^(active-1));
        if isempty(active)
            continue
        end
        A = g.A(active,:);
        lambda = j(take,:)*g.U*A'/(A*A');
        positions = find(take);
        for index = 1:numel(positions)
            keep = active(lambda(index,:) >= -1e-7);
            mode(positions(index)) = sum(2.^(keep-1));
        end
    end
end
% Narrow modes are kept in this log; the first event solve tries the dominant
% face topology. Vertex/overlap hypotheses use the general schedule interface.
changes = find(mode ~= circshift(mode,1));
edges = zeros(1,0);
active = {findFace(mode(1))};
for k = 1:numel(changes)
    index = changes(k);
    if index == 1
        continue
    end
    edges(end+1) = (tau(index)+tau(index-1))/2; %#ok<AGROW>
    active{end+1} = findFace(mode(index)); %#ok<AGROW>
end
schedule = struct('edges',[0 edges 1],'active',{active}, ...
    'source',['HOGA-only ' char(strategy) ' topology hypothesis; never a reference trajectory'], ...
    'seedH',candidate.H,'raw_grid_T',1/numel(tau),'raw_mode_ids',mode, ...
    'raw_support_modes_before_coalescence',rawSupportModes, ...
    'topology_verified',false,'discovery_strategy',char(strategy), ...
    'discovery_voltage_band_rel',0.15,'discovery_current_band_rel',0.14);
end

function face = findFace(index)
face = find(bitget(uint32(index),1:6));
end
