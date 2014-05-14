function alignment = align_xy(sec, varargin)
%ALIGN_XY Aligns the tiles of a section in XY.
% Usage:
%   sec.alignments.xy = align_xy(sec)

% Process parameters
[params, ~] = parse_input(varargin{:});
tic;

if params.verbosity > 0; fprintf('== Aligning section %d in XY\n', sec.num); end

% Merge section matches into a single table
matches = merge_match_sets(sec.xy_matches);

% Solve for alignment relative to rough alignment
[rel_tforms, avg_prior_error, avg_post_error] = sp_lsq(matches, params.fixed_tile);

% Compose with rough transforms
tforms = cellfun(@(rough, rel) compose_tforms(rough, rel), sec.alignments.rough_xy.tforms, rel_tforms, 'UniformOutput', false);

% Save to data structure
alignment.tforms = tforms;
alignment.rel_tforms = rel_tforms;
alignment.rel_to = 'rough';
alignment.meta.fixed_tile = params.fixed_tile;
alignment.meta.avg_prior_error = avg_prior_error;
alignment.meta.avg_post_error = avg_post_error;

if params.verbosity > 0; fprintf('Error: %f -> %fpx / match (%d matches) [%.2fs]\n', avg_prior_error, avg_post_error, sec.xy_matches.num_matches, toc); end

end

function [params, unmatched] = parse_input(varargin)

% Create inputParser instance
p = inputParser;
p.KeepUnmatched = true;

% Alignment
p.addParameter('fixed_tile', 1);

% Verbosity
p.addParameter('verbosity', 1);

% Validate and parse input
p.parse(varargin{:});
params = p.Results;
unmatched = p.Unmatched;

end