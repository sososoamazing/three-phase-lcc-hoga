function out=lcc3_extract_intervals(t,j,threshold_A)
% Extract sampled rectifier conduction windows; edges have grid resolution.
% t is N-by-1 normalized time in [0,1), j is N-by-3 secondary current.
% Positive j = upper diode; negative j = lower diode.
t=t(:);assert(size(j,1)==numel(t) && size(j,2)==3);
if nargin<3 || isempty(threshold_A)
 threshold_A=max(1e-7,1e-4*max(abs(j(:))));
end
N=numel(t);dt=1/N;
labels={'upper_u','upper_v','upper_w','lower_u','lower_v','lower_w', ...
 'any_conducting','all_blocked'};
Irect=.5*sum(abs(j),2);
masks=[j>threshold_A, j<(-threshold_A), ...
 Irect>threshold_A, Irect<=threshold_A];
intervals=struct('mode',{},'start_over_T',{},'end_over_T',{},'duration_over_T',{});
for k=1:size(masks,2)
 b=masks(:,k); d=diff([false;b;false]);
 starts=find(d==1);stops=find(d==-1);
 for m=1:numel(starts)
  a=(starts(m)-1)*dt; c=(stops(m)-1)*dt;
  intervals(end+1)=struct('mode',labels{k},'start_over_T',a, ...
    'end_over_T',c,'duration_over_T',c-a); %#ok<AGROW>
 end
end
out=struct('threshold_A',threshold_A, ...
 'time_resolution_over_T',dt,'intervals',intervals);
end
