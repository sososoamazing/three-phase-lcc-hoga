function result=solve_model(cfg,op,model,seed)
%solve_model Common interface. Each numerical core remains independently coded.
if nargin<4,seed=struct();end
switch upper(string(model))
    case "EDF"
        result=edf_model(cfg,op);
    case "FHA"
        result=fha_model(cfg,op);
    case "HOGA"
        p=hoga_parameters(cfg,op);timer=tic;
        raw=lcc3v2Solve(p,op.Vo,cfg.H,seed);elapsed=toc(timer);
        result=adapt_physical_result(cfg,op,raw,elapsed,'HOGA');
    case "REFERENCE"
        p=hoga_parameters(cfg,op);timer=tic;
        raw=lcc3v2Reference(p,op.Vo,RelTol=1e-10,AbsTol=1e-11,MaxStep_T=1/384,Samples=16384);
        elapsed=toc(timer);result=adapt_physical_result(cfg,op,raw,elapsed,'REFERENCE');
    otherwise
        error('Comparison:UnknownModel','Unknown model %s.',model);
end
end
