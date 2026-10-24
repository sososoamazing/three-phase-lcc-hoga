function lcc3v2CheckParams(p)
%lcc3v2CheckParams Reject unsupported or nonfinite physical and numerical data.
arguments
    p (1,1) struct
end
positive = {'Vin','Ls','Cs','Cp_delta','fs','n_sp','project_sigma_ohm','hoga_tol','reference_tol'};
nonnegative = {'Rin','Vf_rect','event_voltage_tol','event_current_tol'};
for k = 1:numel(positive)
    validateattributes(p.(positive{k}),{'double'},{'real','scalar','finite','positive'},mfilename,positive{k});
end
for k = 1:numel(nonnegative)
    validateattributes(p.(nonnegative{k}),{'double'},{'real','scalar','finite','nonnegative'},mfilename,nonnegative{k});
end
end
