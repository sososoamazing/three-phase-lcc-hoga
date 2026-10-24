function p = lcc3_default_params()
% Parameters for the actual three-leg Delta/Y LCC, SI units.
% Frozen Vo excludes Co and its ESR from the differential equations.
p.Vin=50; p.Rin=1e-3;
p.Ls=4.7e-6; p.Cs=135e-9; p.Cp_delta=27e-9;
p.fs=280e3; p.n_sp=4; p.Vf_rect=0.6;
p.Co_top_background=6.25e-6; p.Co_bottom_background=6.25e-6;
p.ESR_out_background=0.02;
% Numerical settings, not physical parasitics:
p.Nfourier=1024; p.project_sigma_ohm=12;
p.hoga_tol=1e-8; p.reference_steps=3072;
p.reference_tol=1e-8;
end
