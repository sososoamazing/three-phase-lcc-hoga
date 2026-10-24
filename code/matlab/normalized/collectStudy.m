function T=collectStudy(root)
if nargin<1,root=fileparts(fileparts(mfilename('fullpath')));end
files=[dir(fullfile(root,'data','A','*.mat'));dir(fullfile(root,'data','B','*.mat'))];
recovery=dir(fullfile(root,'data','C','*.mat'));
if ~isempty(recovery),files=[files;recovery];end
records=struct([]);
for j=1:numel(files)
    d=load(fullfile(files(j).folder,files(j).name),'record');records=[records d.record]; %#ok<AGROW>
end
T=sortrows(struct2table(records,AsArray=true),{'k_delta','fn','Vo_V'});
writetable(T,fullfile(root,'tables','all_solved_points.csv'));
save(fullfile(root,'data','all_solved_points.mat'),'T','-v7');
fprintf('COLLECT total=%d accepted=%d unresolved=%d\n',height(T),nnz(T.accepted),nnz(~T.accepted));
end
