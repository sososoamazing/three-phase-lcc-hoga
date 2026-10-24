function p=hoga_parameters(cfg,op)
%hoga_parameters Map shared physics onto the unchanged HOGA numeric settings.
p=lcc3v2Params('original_reduced');
fields={'Vin','Ls','Cs','Cp_delta','n_sp','Rin','Vf_rect'};
for k=1:numel(fields),p.(fields{k})=cfg.(fields{k});end
p.fs=op.fs;
end
