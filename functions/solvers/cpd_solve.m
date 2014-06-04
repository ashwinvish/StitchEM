function tform = cpd_solve(ptsA, ptsB, varargin)
%CPD_SOLVE Aligns ptsB to ptsA using CPD.
% Usage:
%   tform = cpd_solve(ptsA, ptsB)
%   tform = cpd_solve(ptsA, ptsB, opt)
%   tform = cpd_solve(ptsA, ptsB, 'Name', Value)
%
% Parameters:
%   'method', 'affine': Transformation type. Can be 'rigid', 'affine', or
%       'nonrigid'.
%   'viz', false: displays visualization
%   'savegif', false: saves visualization into a gif
%   'verbosity', 0: outputs to console
%
% See also: align_z_pair_cpd, sp_lsq

% Default options
methods = {'rigid', 'affine', 'nonrigid', 'nonrigid_lowrank'};
defaults.method = 'affine'; 
defaults.viz = false;
defaults.savegif = false;
defaults.verbosity = 0;
% nonrigid:
defaults.tform_method = 'full';
% nonrigid_lowrank:
defaults.numeig = 30; % number of eigenvectors to leave to estimate G
defaults.eigfgt = true; % use FGT to find eigenvectors (avoids explicitly computing G)

if nargin < 3
    opt = defaults;
else
    if isstruct(varargin{1})
        opt = varargin{1};
    else
        opt = struct(varargin{:});
    end
    
    % Use defaults for any missing options
    for f = fieldnames(defaults)'
        if ~isfield(opt, f{1})
            opt.(f{1}) = defaults.(f{1});
        end
    end
    opt.method = validatestring(opt.method, methods, mfilename);
end

if opt.verbosity > 0; fprintf('Calculating alignment using CPD (%s)...\n', opt.method); end
total_time = tic;

switch opt.method
    case {'rigid', 'affine'}
        % Solve (ptsB -> ptsA)
        T = cpd_register(ptsA, ptsB, opt);
        
        % Return as affine transformation matrix
        tform = affine2d([[T.s * T.R'; T.t'] [0 0 1]']);
        
    case {'nonrigid', 'nonrigid_lowrank'}
        % Solve (inverse: ptsA -> ptsB)
        T = cpd_register(ptsB, ptsA, opt);
        
        % Create CPDNonRigid class
        tform = CPDNonRigid(T, opt.tform_method);
end

if opt.verbosity > 0
    fprintf('Done. Error: <strong>%fpx / match</strong> [%.2fs]\n', rownorm2(ptsB - tform.transformPointsInverse(ptsA)), toc(total_time))
end
end

