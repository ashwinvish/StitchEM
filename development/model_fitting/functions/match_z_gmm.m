function z_matches = match_z_gmm(secA, secB, varargin)
%MATCH_Z_GMM Finds Z matches between two sections and filters using GMM.
% Usage:
%   z_matches = match_z(secA, secB)
%   z_matches = match_z(secA, secB, feature_setA, feature_setB)

% Process parameters
[params, unmatched_params] = parse_input(fieldnames(secA.features), fieldnames(secB.features), varargin{:});

if params.verbosity > 0; fprintf('== Matching Z features between sections %d and %d (GMM)\n', secA.num, secB.num); end
total_time = tic;

% Feature sets
featuresA = secA.features.(params.feature_setA);
featuresB = secB.features.(params.feature_setB);
if params.verbosity > 0; fprintf('Matching feature sets: sec %d -> ''%s'' to sec %d -> ''%s''.\n', secB.num, params.feature_setB, secA.num, params.feature_setA); end

% Find matches between pairs of tiles using NNR
match_sets = cell(secA.num_tiles, secB.num_tiles);
for tA = 1:secA.num_tiles
    % Get tile features
    tile_featsA = featuresA.tiles{tA};
    
    % Match with each tile it overlaps with in secB
    overlapping_tiles = featuresA.meta.overlap_with{tA};
    for tB = overlapping_tiles
        % Get matching tile features
        tile_featsB = featuresB.tiles{tB};
        
        % Find the region numbers of the overlap between the two tiles
        regionA = find(featuresA.meta.overlap_with{tA} == tB, 1);
        regionB = find(featuresB.meta.overlap_with{tB} == tA, 1);
        
        % Skip if we don't have a matching region in either tile
        if isempty(regionA) || isempty(regionB)
            continue
        end
        
        % Get only the features in these regions
        region_featsA = tile_featsA(tile_featsA.region == regionA, :);
        region_featsB = tile_featsB(tile_featsB.region == regionB, :);
        
        % Skip if either has no features
        if isempty(region_featsA) || isempty(region_featsB)
            continue
        end
        
        % Match using Nearest-Neighbor Ratio
        match_set = nnr_match(region_featsA, region_featsB, params.NNR);
        
        % Skip if we didn't find any matches
        if isempty(match_set.A)
            continue
        end
        
        % Get table data from matched indices
        match_set.A = region_featsA(match_set.A, params.keep_cols);
        match_set.B = region_featsB(match_set.B, params.keep_cols);
        
        % Add metadata
        match_set.A.tile = repmat(tA, height(match_set.A), 1);
        match_set.B.tile = repmat(tB, height(match_set.B), 1);
        
        % Save matches
        match_sets{tA, tB} = match_set;
    end
end

% Clear empty cells
match_sets(areempty(match_sets)) = [];

% Merge match sets into one table
nnr_matches.A = table(); nnr_matches.B = table();
for variable = [params.keep_cols {'tile'}]
    varname = variable{1};
    nnr_matches.A.(varname) = cell2mat(cellfun(@(m) m.A.(varname), match_sets, 'UniformOutput', false)');
    nnr_matches.B.(varname) = cell2mat(cellfun(@(m) m.B.(varname), match_sets, 'UniformOutput', false)');
end

% Calculate match displacements
D = nnr_matches.B.global_points - nnr_matches.A.global_points;

% Fit two distributions to data
fit = gmdistribution.fit(D, 2, 'Replicates', 5);

% Cluster data to distributions
% http://www.mathworks.com/help/stats/gmdistribution.cluster.html
k = fit.cluster(D);

% Split data into clusters
D1 = D(k == 1, :);
D2 = D(k == 2, :);

% Choose inlier cluster
switch params.inlier_cluster
    case 'smallest_error'
        % Select the cluster with smallest error as inliers
        D1_norm = rownorm2(D1);
        D2_norm = rownorm2(D2);
        k_inliers = 1; if D1_norm > D2_norm; k_inliers = 2; end
    case 'smallest_var'
        % Select the cluster with the smallest variance as inliers
        k_inliers = 1; if mean(var(D1)) > mean(var(D2)); k_inliers = 2; end
    case 'geomedian'
        % Select the cluster that's closest to the overall geometric median
        D_geomedian = geomedian(D);
        D1_geomedian = geomedian(D1);
        D2_geomedian = geomedian(D2);
        k_inliers = 1;
        if norm(D1_geomedian - D_geomedian) > norm(D2_geomedian - D_geomedian)
            k_inliers = 2;
        end
end

% Keep just the inliers from NNR matching step
z_matches.A = nnr_matches.A(k == k_inliers, :);
z_matches.B = nnr_matches.B(k == k_inliers, :);

% Add metadata
z_matches.num_matches = height(z_matches.A);
z_matches.meta.avg_error = rownorm2(z_matches.B.global_points - z_matches.A.global_points);
z_matches.meta.avg_nnr_error = rownorm2(D);
z_matches.meta.num_nnr_matches = height(nnr_matches.A);
z_matches.meta.all_displacements = D;
z_matches.meta.secA = secA.num;
z_matches.meta.feature_setA = params.feature_setA;
z_matches.meta.alignmentA = featuresA.meta.base_alignment;
z_matches.meta.secB = secB.num;
z_matches.meta.feature_setB = params.feature_setB;
z_matches.meta.alignmentB = featuresB.meta.base_alignment;
z_matches.meta.inlier_clustering_method = params.inlier_cluster;

if params.verbosity > 0; fprintf('Found %d matches. Error before alignment: <strong>%fpx / match</strong>. [%.2fs]\n', z_matches.num_matches, z_matches.meta.avg_error, toc(total_time)); end

end

function [params, unmatched] = parse_input(feature_setsA, feature_setsB, varargin)

% Create inputParser instance
p = inputParser;
p.KeepUnmatched = true;

% Feature sets to use
p.addOptional('feature_setA', feature_setsA{end}, @(x) validatestr(x, feature_setsA));
p.addOptional('feature_setB', feature_setsB{end}, @(x) validatestr(x, feature_setsB));

% NNR
p.addOptional('NNR', struct());

% Columns to keep for the matched features
p.addParameter('keep_cols', {'local_points', 'global_points'});

% Criteria for establishing cluster as inliers
inlier_clustering_methods = {'smallest_error', 'smallest_var', 'geomedian'};
p.addParameter('inlier_cluster', 'geomedian', @(x) validatestr(x, inlier_clustering_methods));

% Verbosity
p.addParameter('verbosity', 1);

% Validate and parse input
p.parse(varargin{:});
params = p.Results;
unmatched = p.Unmatched;

end