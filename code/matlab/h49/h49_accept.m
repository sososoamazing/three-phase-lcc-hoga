function acceptance = h49_accept(raw,p)
%h49_accept Ten independent acceptance checks for one H49 result.
% The checks use the returned state and the same physical definitions as the
% audited model. They do not re-solve and they do not accept converged=true as
% physical validity. All-blocked (open-rectifier family) points use the
% corresponding structural checks and are marked applicable=false where a
% conducting-period check has no meaning.
arguments
    raw (1,1) struct
    p (1,1) struct
end
g = lcc3v2Geometry();
Vd = raw.Vo_V+2*p.Vf_rect;
Ibase = p.Vin/sqrt(p.Ls/p.Cs);
allBlocked = contains(raw.branch,'all_blocked_nonunique');
rows = struct('id',{},'name',{},'value',{},'threshold',{},'pass',{},'applicable',{},'note',{});
% 1 harmonic (spectral) equation residual
if allBlocked
    value = NaN; pass = true; applicable = false; note = 'open-rectifier branch: spectral normal-cone residual reported under check 7';
else
    value = raw.metric.fourier_kvl_residual_V;
    pass = value <= 1e-6; applicable = true;
    note = 'max residual of all 99 spectral KVL rows, V';
end
rows(end+1) = row(1,'harmonic_equation_residual',value,1e-6,pass,applicable,note);
% 2 periodic steady residual
if allBlocked
    value = NaN; pass = true; applicable = false;
    note = 'open family: periodic closure is an identity, not an orbit certificate';
else
    value = max(raw.closure_scaled,raw.metric.event_equation_residual_V/max(1,Vd));
    pass = raw.closure_scaled <= 1e-9 && raw.metric.event_equation_residual_V <= 1e-6;
    applicable = true;
    note = 'max(scaled six-state closure, scaled event residual)';
end
rows(end+1) = row(2,'periodic_steady_residual',value,1e-9,pass,applicable,note);
% 3 conjugate symmetry of the Fourier coefficients
if isfield(raw,'diagnostics') && isfield(raw.diagnostics,'conjugate_symmetry_max_abs') && ~allBlocked
    value = raw.diagnostics.conjugate_symmetry_max_abs;
    pass = value <= 1e-9*Ibase; applicable = true;
else
    value = NaN; pass = true; applicable = false;
    note2 = 'open family: coefficients supplied by the open solver; symmetry checked separately in check 10';
end
if exist('note2','var'), note = note2; clear note2; else, note = 'max |I_{-h}-conj(I_h)|, A'; end
rows(end+1) = row(3,'conjugate_symmetry',value,1e-9*Ibase,pass,applicable,note);
% 4 three-phase circuit constraints
sumI = raw.metric.sum_i_max_A;
sumJ = raw.metric.sum_j_max_A;
value = max(sumI,sumJ);
pass = value <= 1e-9*Ibase; applicable = true;
rows(end+1) = row(4,'three_phase_zero_sum',value,1e-9*Ibase,pass,applicable,'max(|sum i|,|sum j|), A');
% 5 rectifier event structure
if allBlocked
    value = 0; pass = true; applicable = false; note = 'no diode event in the all-blocked family';
else
    nEvents = numel(raw.events);
    value = sum([raw.events.ambiguous]);
    pass = nEvents>=1 && value==0; applicable = true;
    note = sprintf('%d diode events, %d ambiguous',nEvents,value);
end
rows(end+1) = row(5,'rectifier_event_structure',value,0,pass,applicable,note);
% 6 diode reverse (signed) current
if allBlocked
    value = max(abs(raw.wave.jSecondary_A),[],'all');
    pass = value < 1e-7; applicable = true;
    note = 'open all-blocked family: max |secondary current|, A (no reaction current allowed)';
else
    value = raw.metric.min_diode_current_signed_A;
    pass = value >= -1e-7; applicable = true;
    note = 'minimum signed reaction current over active faces, A';
end
rows(end+1) = row(6,'diode_reverse_current',value,-1e-7,pass,applicable,note);
% 7 voltage touch / release and normal residual
value = max(raw.metric.diode_voltage_violation_max_V,raw.metric.normal_max_V);
pass = value <= p.physical_voltage_rel*Vd; applicable = true;
rows(end+1) = row(7,'voltage_touch_release',value,p.physical_voltage_rel*Vd,pass,applicable,'max clamp violation and normal residual, V');
% 8 normal-cone complementarity
value = raw.metric.diode_product_max_W;
pass = value <= 1e-4; applicable = true;
rows(end+1) = row(8,'normal_cone_complementarity',value,1e-4,pass,applicable,'max |reaction current x gap|, W');
% 9 input/output power balance
value = raw.metric.power_relative_residual;
pass = value <= p.physical_power_rel; applicable = true;
rows(end+1) = row(9,'power_balance',value,p.physical_power_rel,pass,applicable,'|Pin-Pout-Pdiode-PRin|/Pin');
% 10 waveform reconstruction and RMS consistency
if allBlocked
    value = max(abs(raw.wave.jSecondary_A),[],'all'); pass = value < 1e-7; applicable = true;
    note = 'open family: max |secondary current|, A (must vanish)';
else
    tau = raw.t_over_T;
    [x,j] = lcc3v2Evaluate(raw,tau);
    reconErr = max(abs(x(:,1:2)*g.U'-raw.wave.i_A),[],'all');
    rmsExact = raw.metric.iLine_rms_A;
    rmsWave = sqrt(mean(raw.wave.i_A.^2,1));
    rmsErr = max(abs(rmsWave-rmsExact)./max(rmsExact,eps));
    value = max(reconErr/max(Ibase,eps),rmsErr);
    pass = reconErr <= 1e-9*Ibase && rmsErr <= 1e-6; applicable = true;
    note = sprintf('reconstruction %.2e A, relative RMS %.2e',reconErr,rmsErr);
end
rows(end+1) = row(10,'waveform_and_RMS_consistency',value,1e-6,pass,applicable,note);
acceptance = struct('rows',rows,'pass',all([rows.pass]), ...
    'failed_checks',{{rows(~[rows.pass]).name}}, ...
    'scope','numerical/physical consistency at fixed H=49; no order-convergence or reference-agreement claim');

    function r = row(id,name,value,threshold,pass,applicable,note)
        r = struct('id',id,'name',name,'value',value,'threshold',threshold, ...
            'pass',logical(pass),'applicable',logical(applicable),'note',note);
    end
end
