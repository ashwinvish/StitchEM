function [matchesA, matchesB, outliersA, outliersB, varargout] = match_section_pair(secA, secB, varargin)
%MATCH_SECTION_PAIR Finds matches between a pair of initialized sections.

% Parse input
[params, unmatched_params] = parse_inputs(varargin{:});

% Match
[matchesA, matchesB, regions, outliersA, outliersB] = match_feature_sets(secA.features, secB.features, ...
    'grid_aligned', {secA.grid_aligned, secB.grid_aligned}, unmatched_params);

%% Visualize matches
if params.show_matches || params.show_outliers
    disp('Rendering merged sections.')
    
    % Render the section tiles
    [secA_rough, secA_rough_R] = imshow_section(secA, 'display_scale', params.display_scale, 'suppress_display', true);
    [secB_rough, secB_rough_R] = imshow_section(secB, 'display_scale', params.display_scale, 'suppress_display', true);
    [rough_registration, rough_registration_R] = imfuse(secA_rough, secA_rough_R, secB_rough, secB_rough_R);
    
    % Return merged image
    varargout = {rough_registration, rough_registration_R};
end

if params.show_matches
    % Show the merged rough aligned tiles
    figure, imshow(rough_registration, rough_registration_R), hold on

    % Show the matches
    plot_matches(matchesA.global_points, matchesB.global_points, params.display_scale)

    % Adjust the figure
    title(sprintf('Matches between sections %d and %d (n = %d)', secA.num, secB.num, size(matchesA, 1)))
    integer_axes(1/params.display_scale)
    hold off
    
    % Show regions
    if params.show_regions
        hold on
        region_corners = transformPointsForward(scale_tform(params.display_scale), cell2mat(regions));
        plot(region_corners(:, 1), region_corners(:, 2), 'w+', 'MarkerSize', 10)
        hold off
    end
    
    varargout = {rough_registration, rough_registration_R};
end
if params.show_outliers
    % Show the merged rough aligned tiles
    figure, imshow(rough_registration, rough_registration_R), hold on

    % Show the outliers
    plot_matches(outliersA.global_points, outliersB.global_points, params.display_scale)
    
    % Adjust the figure
    title(sprintf('Outliers between sections %d and %d (n = %d)', secA.num, secB.num, size(outliersA, 1)))
    integer_axes(1/params.display_scale)
    hold off
    
    % Show regions
    if params.show_regions
        hold on
        region_corners = transformPointsForward(scale_tform(params.display_scale), cell2mat(regions));
        plot(region_corners(:, 1), region_corners(:, 2), 'w+', 'MarkerSize', 10)
        hold off
    end
end
if params.show_stats
    match_stats = matching_stats(matchesA, matchesB, outliersA, outliersB);
    disp(match_stats.tile_summary)
    
    varargout{end + 1} = match_stats;
end
end

function [params, unmatched] = parse_inputs(varargin)
% Create inputParser instance
p = inputParser;
p.KeepUnmatched = true;

% Visualization
p.addParameter('show_matches', false);
p.addParameter('show_outliers', false);
p.addParameter('show_regions', false);
p.addParameter('display_scale', 0.075);

% Match Statistics
p.addParameter('show_stats', false);

% Validate and parse input
p.parse(varargin{:});
params = p.Results;
unmatched = p.Unmatched;
end