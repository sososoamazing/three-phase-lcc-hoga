function result = lcc3v2Solve(p,Vo,H,seed)
%lcc3v2Solve Try HOGA-derived mode hypotheses and retain rejected topologies.
arguments
    p (1,1) struct
    Vo (1,1) double {mustBePositive,mustBeFinite}
    H (1,1) double {mustBeInteger,mustBePositive}
    seed (1,1) struct = struct()
end
first = lcc3v2Hoga(p,Vo,H,seed);
result = first;
if first.physical_guard_pass
    return
end
% This additional hypothesis is generated from another HOGA solve. It does
% not access, load or accept independent reference events/waveforms.
discovery = solve_three_phase_lcc_hoga(p,Vo,7,[]);
proposal = lcc3v2Discover(discovery,p,Vo,'support_coalesced');
g = lcc3v2Geometry();
newSeed = struct('event_schedule',proposal,'method','Fourier support topology proposal', ...
    'Vo_V',Vo,'e_initial_alpha_beta',g.U'*discovery.wave.vSec_V(1,:).');
try
    result = lcc3v2Hoga(p,Vo,H,newSeed);
    result.rejected_topology = struct('status',first.status,'metric',first.metric, ...
        'event_schedule',first.event_schedule,'solver_history',first.solver_history);
catch err
    result.failed_support_hypothesis = struct('status','FAIL','schedule',proposal,'message',getReport(err));
end
if result.physical_guard_pass
    return
end
if isfield(first.metric,'min_diode_current_signed_A') && ...
        first.metric.min_diode_current_signed_A < -1e-7
    release = lcc3v2Discover(first,p,Vo,'release');
    releaseSeed = struct('event_schedule',release,'method','Fourier signed-reaction release proposal', ...
        'Vo_V',Vo,'e_initial_alpha_beta',first.e_initial_alpha_beta);
    previous = result;
    try
        result = lcc3v2Hoga(p,Vo,H,releaseSeed);
        result.rejected_topology = struct('status',first.status,'metric',first.metric, ...
            'event_schedule',first.event_schedule,'solver_history',first.solver_history);
        result.support_topology_attempt = struct('status',previous.status,'metric',previous.metric, ...
            'event_schedule',previous.event_schedule,'solver_history',previous.solver_history);
    catch err
        result.failed_release_hypothesis = struct('status','FAIL','schedule',release,'message',getReport(err));
    end
end
end
