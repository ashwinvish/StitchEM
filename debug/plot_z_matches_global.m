function plot_z_matches_global(secA, secB)
% Plots the z matches between a pair of sections in both z alignments.

figure
plot_section(secA, 'z', 'r0.1')
plot_section(secB, 'z', 'g0.1')
matches.A = tform_z_matches(secA, secB.z_matches.A);
matches.B = tform_z_matches(secB, secB.z_matches.B);
% outliers.A = tform_z_matches(secA, secB.z_matches.outliers.A);
% outliers.B = tform_z_matches(secB, secB.z_matches.outliers.B);
plot_matches(matches)
% plot_matches_vectors(matches)
% plot_matches(outliers.A, outliers.B, 1.0, true)

end

function matches = tform_z_matches(sec, matches)
% Put the B points into the proper space for display

for i = 1:sec.num_tiles
    tform = sec.alignments.z.tforms{i};
    pts = matches.local_points(matches.tile == i, :);
    tform_pts = transformPointsForward(tform, pts);
    matches.global_points(matches.tile == i, :) = tform_pts;
end

end