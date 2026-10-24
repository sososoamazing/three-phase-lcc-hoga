function runRecoveryStudy(tag)
% Recovery pass for every unique point that is still UNRESOLVED after stage B.
% Results are written to data/C/<tag-free standard name> and nothing on disk is
% overwritten: an existing data/C file makes the driver skip that point, so the
% run is resumable and the historical A/B failures stay untouched.
%
% Only the seed strategy changes (cross-frequency and chained continuation);
% the physical guard and the H15->31->63 order check are identical to
% studyPointRefined. A point that still fails stays UNRESOLVED and is reported.
if nargin<1,tag='C';end
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'core'),fullfile(root,'legacy'),fullfile(root,'scripts'));
if ~isfolder(fullfile(root,'data',tag)),mkdir(fullfile(root,'data',tag));end
T=readtable(fullfile(root,'tables','characteristic_domain.csv'),TextType='string');
accepted=toLogical(T.accepted);
sel=~accepted;
targets=[T.Vo_V(sel) T.fn(sel) T.k_delta(sel)];
keys=unique(targets(:,2:3),'rows');
fprintf('RECOVERY_TARGETS %d points in %d (fn,k) groups\n',size(targets,1),size(keys,1));
jobs=cell(size(keys,1),1);
for j=1:size(keys,1)
    on=abs(targets(:,2)-keys(j,1))<1e-10 & abs(targets(:,3)-keys(j,2))<1e-10;
    jobs{j}=sortrows(targets(on,:),1);
    fprintf('  group fn=%.3f k=%.3g : %d points\n',keys(j,1),keys(j,2),size(jobs{j},1));
end
pool=gcp('nocreate');
if isempty(pool)
    cluster=parcluster('local');cluster.JobStorageLocation=fullfile(root,'runtime','jobs');
    pool=parpool(cluster,4);
end
futures=parallel.FevalFuture.empty();
for j=1:numel(jobs),futures(j)=parfeval(pool,@runGroup,0,root,jobs{j},tag);end
for j=1:numel(futures)
    try
        fetchNext(futures);
    catch err
        fprintf('RECOVERY_GROUP_ERROR %s\n',err.message);
    end
    fprintf('GROUP %s %d/%d\n',tag,j,numel(futures));
end
collectStudy(root);
end

function runGroup(root,jobs,tag)
addpath(fullfile(root,'core'),fullfile(root,'legacy'),fullfile(root,'scripts'));maxNumCompThreads(1);
cache=containers.Map('KeyType','char','ValueType','any');
extraSeeds={};
for j=1:size(jobs,1)
    Vo=jobs(j,1);fn=jobs(j,2);k=jobs(j,3);
    file=fullfile(root,'data',tag,sprintf('V%07.2f_F%06.3f_K%06.3f.mat',Vo,fn,k));
    if isfile(file)
        d=load(file,'record','solution');
        if d.record.accepted,extraSeeds{end+1}=struct('Vo',Vo,'fn',fn,'solution',d.solution);end %#ok<AGROW>
        continue
    end
    try
        [r,s]=studyPointRecovery(root,Vo,fn,k,extraSeeds,cache,tag);
        if r.accepted
            extraSeeds{end+1}=struct('Vo',Vo,'fn',fn,'solution',s); %#ok<AGROW>
        end
    catch err
        fprintf('RECOVERY_POINT_ERROR V=%g fn=%.3f k=%.3g %s\n',Vo,fn,k,err.message);
    end
end
end

function v=toLogical(x)
if islogical(x),v=x;return;end
if isnumeric(x),v=x~=0;return;end
s=lower(string(x));v=s=="true"|s=="1"|s=="yes";
end
