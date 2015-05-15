function stats = plot_xy_matches_stats(sec)
% Plot correspondence stats dataset for distributions

% Inputs:
%   sec: the section with xy matches & alignment
%
% Outputs:
%   stats: dataset object containing the transformed points and the
%   computations that led to the plot
%
% There should be a tight distribution between points in the same overlap.
% If points do not closely clump in the same overlap, then there is likely
% a poor match that should be investigated.

tformsA = sec.alignments.xy.tforms;
tformsB = sec.alignments.xy.tforms;
stats = calculate_matches_stats(sec.xy_matches, tformsA, tformsB);

group_stats = grpstats(stats,'pair',{'mean', 'std', 'median'},'DataVars',{'dist','ang'});

pairs = unique([stats.tileA stats.tileB], 'rows');

name = sprintf('%s plot_xy_matches_stats', sec.name);
figure('name', name);
subplot(2, 1, 1);
scatter(stats.pair, stats.dist);
hold on
scatter(group_stats.pair, group_stats.mean_dist, '*', 'MarkerEdgeColor', [1 0 0]);
scatter(group_stats.pair, group_stats.median_dist, '*', 'MarkerEdgeColor', [0 1 0]);
% legend('correspondences', 'mean', 'Location', 'best');
set(gca, 'Xtick', 1:length(pairs));
labels = cellfun(@num2str, num2cell(pairs, 2), 'UniformOutput', false);
set(gca, 'XTickLabel', labels);
title('Euclidean distance between corresponding points')
xlabel('Tile pairs (A B)');
ylabel('Distance (px)');
grid on

subplot(2, 1, 2);
scatter(stats.pair, stats.ang)
set(gca, 'Xtick', [1:1:size(pairs, 1)]);
labels = cellfun(@num2str, num2cell(pairs, 2), 'UniformOutput', false);
set(gca, 'XTickLabel', labels);
title('Direction of vector between corresponding points')
xlabel('Tile pairs (A B)');
ylabel('Angle B-to-A (rad)');
grid on