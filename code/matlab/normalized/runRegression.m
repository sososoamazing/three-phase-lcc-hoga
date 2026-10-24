function runRegression()
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'core'),fullfile(root,'legacy'),fullfile(root,'scripts'));
maxNumCompThreads(1);
source=fullfile(fileparts(root),'hoga_audit_v2_20261014','results','final_release_v23');
records=struct([]);
for item=[100 15;400 31;800 31].'
    Vo=item(1);H=item(2);
    d=load(fullfile(source,sprintf('hoga_Vo%d_H%d.mat',Vo,H)));
    seed=d.hoga;p=lcc3v2Params('original_reduced');
    fast=studyHoga(p,Vo,H,seed);
    original=lcc3v2Hoga(p,Vo,H,seed);
    c=lcc3v2Compare(fast,original);
    r=struct('Vo_V',Vo,'H',H,'Io_relative',c.Irect_mean_A_relative, ...
        'Im_relative',c.iLine_peak_A_relative,'Irms_relative',c.iLine_rms_A_relative, ...
        'event_time_T',c.event_time_max_T,'topology_match',c.event_topology_match, ...
        'guard_match',fast.physical_guard_pass==original.physical_guard_pass);
    r.pass=r.Io_relative<1e-8 && r.Im_relative<1e-7 && r.Irms_relative<1e-8 && ...
        r.event_time_T<1e-7 && r.topology_match && r.guard_match;
    records=[records r]; %#ok<AGROW>
    save(fullfile(root,'audit',sprintf('regression_V%g_H%d.mat',Vo,H)),'r','fast','original','-v7');
    writetable(struct2table(records),fullfile(root,'audit','implementation_regression.csv'));
    fprintf('REGRESSION V=%g H=%d pass=%d IoErr=%g ImErr=%g\n',Vo,H,r.pass,r.Io_relative,r.Im_relative);
    assert(r.pass,'Study:Regression','Implementation failed source equivalence.');
end
fid=fopen(fullfile(root,'audit','regression_pass.json'),'w');fprintf(fid,'%s',jsonencode(records));fclose(fid);
end
