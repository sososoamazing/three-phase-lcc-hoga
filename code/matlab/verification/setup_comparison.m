function setup_comparison(root)
%setup_comparison Add only the selected isolated implementation directories.
if nargin<1,root=fileparts(fileparts(mfilename('fullpath')));end
addpath(fullfile(root,'01_common'),fullfile(root,'02_HOGA','validated_model'),fullfile(root,'02_HOGA','legacy'), ...
    fullfile(root,'03_EDF'),fullfile(root,'04_FHA'),fullfile(root,'05_verification'));
end
