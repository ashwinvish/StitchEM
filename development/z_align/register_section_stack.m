first_sec_num = 100;
num_secs = 5;

secs = cell(num_secs, 1);
matches = cell(num_secs-1, 2);
match_stats = cell(num_secs-1, 1);
merges = cell(num_secs, 1);
merges_R = cell(num_secs, 1);

%% Initialize
for i = 1:num_secs-1
    if i == 1
        [secs{i}, secs{i + 1}] = initialize_section_pair(first_sec_num + i - 1, first_sec_num + i, 'tile_resize_scale', 0.125, 'detection_scale', 0.125, 'MetricThreshold', 1000);
    else
        [secs{i}, secs{i + 1}] = initialize_section_pair(secs{i}, first_sec_num + i, 'tile_resize_scale', 0.125, 'detection_scale', 0.125, 'MetricThreshold', 1000);
    end
end

%% Match
for i = 1:num_secs-1
    [matchesA, matchesB, outliersA, outliersB] = match_section_pair(secs{i}, secs{i + 1});
    match_stats{i} = matching_stats(matchesA, matchesB, outliersA, outliersB);
    
    matches{i, 1} = matchesA; matches{i, 2} = matchesB;
end

matchesA = vertcat(matches{:, 1});
matchesB = vertcat(matches{:, 2});

%% Lambda curve
lambda_curve(matchesA, matchesB);

%% Align
[secs, mean_error] = align_section_stack(secs, matchesA, matchesB, 'lambda', 0.05);

%% Render
% Render section merges
merges = cell(num_secs, 1);
merges_R = cell(num_secs, 1);
for i = 1:num_secs
    [merges{i}, merges_R{i}] = imshow_section(secs{i}, 'tforms', 'fine', 'suppress_display', true);
end

% Save merges
%i=1;imwrite(merges{i}, sprintf('sec%d_aligned.tif', secs{i}.num));

% Render and save blends
%i = 1; imwrite(imfuse(merges{i}, merges_R{i}, merges{i + 1}, merges_R{i + 1}), sprintf('sec%d-%d_aligned.png', secs{i}.num, secs{i+1}.num));