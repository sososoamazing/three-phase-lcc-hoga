function comparison = lcc3v2Compare(a,b)
%lcc3v2Compare Absolute, ordinary relative and topology-aware event differences.
arguments
    a (1,1) struct
    b (1,1) struct
end
names = {'Irect_mean_A','iLine_rms_A','iLine_peak_A','jSec_rms_A', ...
    'jSec_peak_A','vCs_peak_V','vDelta_peak_V'};
comparison = struct();
for k = 1:numel(names)
    name = names{k};
    delta = abs(a.metric.(name)-b.metric.(name));
    comparison.([name '_absolute']) = max(delta);
    if all(abs(b.metric.(name)) > 1e-6)
        comparison.([name '_relative']) = max(delta./abs(b.metric.(name)));
    else
        comparison.([name '_relative']) = NaN;
    end
end
waveNames = {'i_A','vCs_V','vDelta_V','jSecondary_A'};
for k = 1:numel(waveNames)
    name = waveNames{k};
    reference = b.wave.(name);
    if numel(a.t_over_T) ~= numel(b.t_over_T) || ...
            max(abs(a.t_over_T-b.t_over_T)) > 1e-14
        reference = interp1([b.t_over_T(end)-1;b.t_over_T;b.t_over_T(1)+1], ...
            [reference(end,:);reference;reference(1,:)],a.t_over_T,'linear');
    end
    comparison.([name '_wave_relative_L2']) = norm(a.wave.(name)-reference,'fro')/max(1e-12,norm(reference,'fro'));
end
ea = a.events(strcmp({a.events.kind},'diode'));
eb = b.events(strcmp({b.events.kind},'diode'));
comparison.event_count_a = numel(ea);
comparison.event_count_b = numel(eb);
comparison.event_topology_match = numel(ea)==numel(eb);
comparison.event_time_max_T = NaN;
comparison.event_time_max_s = NaN;
if comparison.event_topology_match && ~isempty(ea)
    errors = zeros(1,numel(ea));
    used = false(1,numel(eb));
    for k = 1:numel(ea)
        matches = find(arrayfun(@(e)isequal(sort(e.before),sort(ea(k).before)) && ...
            isequal(sort(e.after),sort(ea(k).after)),eb) & ~used);
        if isempty(matches)
            comparison.event_topology_match = false;
            break
        end
        distance = abs(mod(ea(k).tau-[eb(matches).tau]+0.5,1)-0.5);
        [errors(k),index] = min(distance);
        used(matches(index)) = true;
    end
    if comparison.event_topology_match
        comparison.event_time_max_T = max(errors);
        comparison.event_time_max_s = max(errors)/a.params.fs;
    end
elseif comparison.event_topology_match
    comparison.event_time_max_T = 0;
    comparison.event_time_max_s = 0;
end
end
