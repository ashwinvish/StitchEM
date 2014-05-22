function sec = load_overview(sec, scale)
%LOAD_OVERVIEW Loads the overview image of a section at the specified scale.
% Usage:
%   sec = load_overview(sec, scale)

load_time = tic;

sec.overview.img = imload_overview(sec.num, scale);
sec.overview.size = imsize(get_overview_path(sec.num)); % get unscaled size
sec.overview.scale = scale;

fprintf('Loaded overview (%sx) in section %d. [%.2fs]\n', num2str(scale), sec.num, toc(load_time))

end

