function p = lcc3v2Params(baseline)
%lcc3v2Params Physical parameters and separately identified numerical settings.
arguments
    baseline (1,1) string {mustBeMember(baseline,["original_reduced","ideal"])} = "original_reduced"
end
p.version = 'LCC3-FIXEDVO-V2.3-20261014';
p.baseline = char(baseline);
p.Vin = 50;
p.Rin = 1e-3;
p.Ls = 4.7e-6;
p.Cs = 135e-9;
p.Cp_delta = 27e-9;
p.fs = 280e3;
p.n_sp = 4;
p.Vf_rect = 0.6;
if baseline == "ideal"
    p.Rin = 0;
    p.Vf_rect = 0;
end
p.Nfourier = 1536;
p.project_sigma_ohm = 12;
p.hoga_tol = 1e-9;
p.reference_tol = 1e-8;
p.reference_steps = 1536;
p.event_voltage_tol = 2e-7;
p.event_current_tol = 1e-10;
p.physical_voltage_rel = 1e-3;
p.physical_power_rel = 1e-3;
p.order_integral_rel = 0.01;
p.order_peak_rel = 0.02;
p.event_time_tol_T = 1e-3;
end
