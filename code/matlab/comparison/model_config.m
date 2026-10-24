function cfg=model_config
%model_config Single SI parameter source for the audited 50 V Delta/Y circuit.
cfg=struct('Vin',50,'Ls',4.7e-6,'Cs',135e-9,'Cp_delta',27e-9, ...
    'n_sp',4,'fs',280e3,'Rin',1e-3,'Vf_rect',0.6,'Co_actual',3.125e-6);
cfg.baseline='original_reduced';
cfg.drive='upper A/B/C: positive phases 0,+120,+240 deg; complementary, zero deadtime';
cfg.topology='three legs, Delta Cp/primary, floating Y secondary, six-diode bridge';
cfg.H=31;cfg.samples=8192;
cfg.Vo_points=[100 200 300 400 500 600 700 800];
cfg.frequency_points=[240 260 280 300 320]*1e3;
cfg.typical_voltages=[100 400 800];
cfg.normalization_Io=1; % A, fixed near-zero-safe error base
cfg.normalization_Ir=cfg.Vin/sqrt(cfg.Ls/cfg.Cs);
cfg.root=fileparts(fileparts(mfilename('fullpath')));
cfg.project=fileparts(cfg.root);
cfg.source_slx=fullfile(cfg.project,'MATLAB_PRJ','three_phase','simulink','three_phase_LCC.slx');
cfg.source_sha256='807db96a073d18972c1fe0242bf7576570b5e862bdfc8a61c8d03aff8e28faa0';
end
