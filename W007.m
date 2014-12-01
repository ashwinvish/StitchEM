%% Configuration
% Wafer and sections
waferpath('/mnt/data0/ashwin/07122012/S2-W007')

% Analyze path
info = get_path_info(waferpath);
status.wafer = info.wafer;
status.pipeline_script = mfilename;
sec_nums = info.sec_nums;

% Skip sections
%sec_nums(103) = []; % skip

% Load default parameters
default_params

%% Custom per-section parameters
% Note: The index of params corresponds to the actual section number.
% 
% Example:
%   => Change the NNR MaxRatio of section 38:
%   params(38).z.NNR.MaxRatio = 0.8;
%
%   => Set the max match error for sections 10 to 15 to 2000:
%   params(10).z.max_match_error = 2000; % change section 10's parameters
%   [params(11:15).z] = deal(params(10).z); % copy it to sections 11-15
%       Or:
%   for s=10:15; params(s).z.max_match_error = 2000; end

% S2-W007
% XY
% params(2).xy = xy_presets.grid_align;
% params(9).xy = xy_presets.grid_align;
% params(10).xy = xy_presets.grid_align;
% params(10).xy.matching.filter_method = 'gmm';
% params(10).xy.matching.filter_fallback = 'geomedian';
% for s=11:length(params); params(s).xy = xy_presets.grid_align; end
% params(12).xy.matching.filter_method = 'gmm';
% params(12).xy.matching.filter_fallback = 'geomedian';
%% Run alignment
% try
    align_stack_xy
%     align_stack_z
% catch alignment_error
%     troubleshoot
% end