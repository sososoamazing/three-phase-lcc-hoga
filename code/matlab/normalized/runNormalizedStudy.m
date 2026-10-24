function runNormalizedStudy(stage)
if nargin<1,stage='A';end
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'core'),fullfile(root,'legacy'),fullfile(root,'scripts'));
assert(isfile(fullfile(root,'audit','regression_pass.json')),'Study:Gate','Run source regression before new scans.');
if strcmp(stage,'A')
    groups=[(1:.1:2).' .2*ones(11,1)];
    for k=[.1 .35 .5 .8 1],groups(end+1,:)=[1.4 k];end %#ok<AGROW>
    volts=0:50:800;
    jobs=cell(size(groups,1),1);
    for j=1:size(groups,1),jobs{j}=[volts.' repmat(groups(j,:),numel(volts),1)];end
else
    T=readtable(fullfile(root,'tables','adaptive_plan.csv'));
    keys=unique([T.fn T.k_delta],'rows');jobs=cell(size(keys,1),1);
    for j=1:size(keys,1)
        selected=abs(T.fn-keys(j,1))<1e-10 & abs(T.k_delta-keys(j,2))<1e-10;
        jobs{j}=sortrows([T.Vo_V(selected) T.fn(selected) T.k_delta(selected)],1);
    end
end
pool=gcp('nocreate');
if isempty(pool)
    cluster=parcluster('local');cluster.JobStorageLocation=fullfile(root,'runtime','jobs');pool=parpool(cluster,4);
end
futures=parallel.FevalFuture.empty();
for j=1:numel(jobs),futures(j)=parfeval(pool,@runGroup,0,root,jobs{j},stage);end
for j=1:numel(futures),fetchNext(futures);fprintf('GROUP %s %d/%d\n',stage,j,numel(futures));end
collectStudy(root);
end

function runGroup(root,jobs,stage)
addpath(fullfile(root,'core'),fullfile(root,'legacy'),fullfile(root,'scripts'));maxNumCompThreads(1);
seed=struct();
for j=1:size(jobs,1)
    Vo=jobs(j,1);fn=jobs(j,2);k=jobs(j,3);
    file=fullfile(root,'data',stage,sprintf('V%07.2f_F%06.3f_K%06.3f.mat',Vo,fn,k));
    if isfile(file)
        d=load(file,'record','solution');if d.record.accepted,seed=d.solution;end
        continue
    end
    if strcmp(stage,'B')
        [r,s]=studyPointRefined(root,Vo,fn,k,seed,stage);
    else
        [r,s]=studyPoint(root,Vo,fn,k,seed,stage);
    end
    if r.accepted,seed=s;end
end
end
