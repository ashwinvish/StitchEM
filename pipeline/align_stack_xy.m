%% Rough & XY Alignment
if ~exist('params'); error('The ''params'' variable does not exist. Load parameters before doing alignment.'); end
if ~exist('secs'); secs = cell(length(sec_nums), 1); end
if ~exist('error_log'); error_log = {}; end
error_log = {};

disp('==== <strong>XY alignment</strong>.')
for s = start:finish
    sec_timer = tic;
    
    % Parameters
    xy_params = params(sec_nums(s)).xy;
    
    fprintf('=== Aligning %s (<strong>%d/%d</strong>) in XY\n', get_path_info(get_section_path(sec_nums(s)), 'name'), s, length(sec_nums))
    
    % Check for overwrite
    % TO DO
    
    % Section structure
    if length(secs) < s ~exist('sec') || sec.num ~= sec_nums(s)
        % Create a new section structure
        sec = load_section(sec_nums(s), 'skip_tiles', xy_params.skip_tiles, 'wafer_path', waferpath());
    else
        % Use section in the workspace
    	sec = secs{s};
        disp('Using section that was already loaded. Clear ''sec'' to force section to be reloaded.')
    end
    
    % Load images
    if ~isfield(sec.tiles, 'full'); sec = load_tileset(sec, 'full', 1.0); end
    if ~isfield(sec.tiles, 'rough'); sec = load_tileset(sec, 'rough', xy_params.rough.overview_registration.tile_scale); end
    if isempty(sec.overview) || ~isfield(sec.overview, 'img') || isempty(sec.overview.img) ...
            || ~isfield(sec.overview, 'scale') || sec.overview.scale ~= xy_params.rough.overview_registration.overview_scale
        sec = load_overview(sec, xy_params.rough.overview_registration.overview_scale);
    end
    
    % Rough alignment
    sec.alignments.rough_xy = rough_align_xy(sec, xy_params.rough);

    % Detect XY features
    sec.features.xy = detect_features(sec, 'alignment', 'rough_xy', 'regions', 'xy', xy_params.features);
    
    % Match XY features
    sec.xy_matches = match_xy(sec, 'xy', xy_params.matching);
    
    % Setup the error log
    sec.error_log = [];
    
    % Flag bad matching
    if sec.xy_matches.meta.avg_error > xy_params.max_match_error
        disp('<strong>FLAG</strong> XY matches distance beyond threshold');
        sec.error_log{end+1} = sprintf('%s: sec.xy_matches.meta.avg_error > xy_params.max_match_error', sec.name);
    end
    if ~isempty(find_orphan_tiles(sec, 'xy'))
        disp('<strong>FLAG</strong> XY orphan tiles');
        sec.error_log{end+1} = sprintf('%s: orphan tiles', sec.name);
    end

    try
        % Align XY
        sec.alignments.xy = align_xy(sec, xy_params.align);
        
        % Flag bad alignment
        if sec.alignments.xy.meta.avg_post_error > xy_params.max_aligned_error
            disp('<strong>STOP</strong> XY overall alignment error beyond threshold');
            sec.error_log{end+1} = sprintf('%s: sec.alignments.xy.meta.avg_post_error > xy_params.max_aligned_error', sec.name);
        end
    catch
        fprintf('Failed xy alignment for %s_Sec%d', sec.wafer, sec.num);
    end
    
    % Clear images and XY features to save memory
    sec = imclear_sec(sec);
    sec.features.xy.tiles = [];
    
    % Save
    sec.params.xy = xy_params;
    sec.runtime.xy.time_elapsed = toc(sec_timer);
    sec.runtime.xy.timestamp = datestr(now);
    secs{s} = sec;
    clear sec
end


total_xy_time = sum(cellfun(@(sec) sec.runtime.xy.time_elapsed, secs));
fprintf('==== <strong>Finished XY alignment in %.2fs (%.2fs / section)</strong>.\n\n', total_xy_time, total_xy_time / length(secs));
disp('=== <strong>Finished XY alignemnt</strong> ====');
