function current_path = renderpath(new_path)
%RENDERPATH Gets or sets the renders path.
% Usage:
%   current_path = renderpath
%   renderpath(new_path)

global ProgramPaths;

% Update
if nargin > 0
    ProgramPaths.renders = GetFullPath(new_path);
    disp('Set render path.')
end

% Defaults
if isempty(ProgramPaths) || ~isfield(ProgramPaths, 'base')
    ProgramPaths.base = GetFullPath(fullfile(mfilename('fullpath'), '../../..'));
    ProgramPaths.rough_xy = fullfile(ProgramPaths.base, 'rough_xy');
    ProgramPaths.xy = fullfile(ProgramPaths.base, 'xy');
    ProgramPaths.rough_z = fullfile(ProgramPaths.base, 'rough_z');
    ProgramPaths.overview_rough_z = fullfile(ProgramPaths.base, 'overview_rough_z');
    ProgramPaths.z = fullfile(ProgramPaths.base, 'z');
end

% Return current
current_path = ProgramPaths;
end

