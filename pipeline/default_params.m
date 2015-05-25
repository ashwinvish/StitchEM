%% Defaults: XY alignment
% General
defaults.xy.overwrite = true; % throws error if section is already XY aligned
defaults.xy.skip_tiles = [];

% [rough_align_xy] Rough alignment
defaults.xy.rough.align_to_overview = true;
defaults.xy.rough.overview_registration.overview_to_tile_resolution_ratio = 0.07;
defaults.xy.rough.overview_registration.overview_scale = 0.78;
defaults.xy.rough.overview_registration.overview_crop_ratio = 0.5;
defaults.xy.rough.overview_registration.overview_cropping = [0.25 0.25 0.5 0.5];

% [detect_features] Feature detection
defaults.xy.features.detection_scale = 1.0;
defaults.xy.features.min_overlap_area = 0.02;
defaults.xy.features.SURF.MetricThreshold = 11000; % for full res tiles

% [match_xy] Matching: NNR
defaults.xy.matching.NNR.MaxRatio = 0.6;
defaults.xy.matching.NNR.MatchThreshold = 1.0;

% [match_xy] Matching: Outlier filtering
defaults.xy.matching.filter_method = 'geomedian'; % 'geomedian', 'gmm' or 'none'
defaults.xy.matching.filter_fallback = 'none';
defaults.xy.matching.keep_outliers = true;
defaults.xy.matching.geomedian.cutoff = '1.25x';
defaults.xy.matching.GMM.inlier_cluster = 'smallest_var';
defaults.xy.matching.GMM.warning = 'error';
defaults.xy.matching.GMM.Replicates = 5;

% [align_xy] Alignment
defaults.xy.align.fixed_tile = 1;

% Quality control checks
defaults.xy.max_match_error = 100; % avg error after matching
defaults.xy.max_aligned_error = 5; % avg error after alignment
defaults.xy.ignore_error = true; % still throws warning if true

%% Defaults: Z alignment
% General
defaults.z.overwrite = true; % throws error if section is already Z aligned
defaults.z.rel_to = -1; % relative section to align to
defaults.z.scale = 0.125;
defaults.z.SURF.MetricThreshold = 2000;

% [detect_features] Feature detection (0.125x)
defaults.z.features.scale = 0.125;
defaults.z.features.SURF.MetricThreshold = 2000;

% Matching
defaults.z.matching_mode = 'auto'; % 'auto' or 'manual'

% [match_z] Matching: NNR
defaults.z.matching.NNR.MaxRatio = 0.6;
defaults.z.matching.NNR.MatchThreshold = 1.0;

% [match_z] Matching: Outlier filtering
defaults.z.matching.filter_method = 'gmm'; % 'geomedian', 'gmm' or 'none'
defaults.z.matching.filter_fallback = 'geomedian';
defaults.z.matching.keep_outliers = true;
defaults.z.matching.geomedian.cutoff = '1.25x';
defaults.z.matching.GMM.inlier_cluster = 'geomedian';
defaults.z.matching.GMM.warning = 'off';
defaults.z.matching.GMM.Replicates = 5;

% Alignment
defaults.z.alignment_method = 'cpd'; % 'lsq', 'cpd' or 'fixed'

% Quality control checks
defaults.z.max_match_error = 1000; % avg error after matching
defaults.z.max_aligned_error = 50; % avg error after alignment
defaults.z.ignore_error = true; % only throws warning if true

%% Initialize parameters with defaults
params = repmat(defaults, max(sec_nums), 1);