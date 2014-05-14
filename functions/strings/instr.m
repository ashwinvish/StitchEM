function TF = instr(needle, haystack, flags)
%INSTR Returns true if (any) needle is in (any) haystack.
%
% Usage:
%   TF = instr(needle, haystack)
%   TF = instr(needle, haystack, flags)
%
% Args:
%   needle is a string or cell array of strings to look for.
%   haystack is the string or cell array of strings to look in.
%   flags indicates the matching mode:
%       's' => True if needle is a substring of haystack (default)
%       'r' => True if regexp(needle, haystack) returns a match
%       'e' => Looks for exact match
%
%       You can combine these with the modifier flags:
%       'c' => Case-sensitive
%       'a' => Evaluate ALL needles
%
% Returns:
%   TF logical indicating if needle is in haystack.
%       If either the needle or the haystack are cell arrays and the 'a'
%       flag is not set (default), this function returns a scalar
%       indicating whether ANY needle was found in ANY haystack.
%
% See also: strcmp, strfind, validatestr, regexp

% Parse input
narginchk(2, 3)
if nargin < 3; flags = 's'; else flags = lower(flags); end
valid_flags = 'rseca';
p = inputParser;
p.addRequired('needle', @(x) ischar(x) || iscellstr(x));
p.addRequired('haystack', @(x) ischar(x) || iscellstr(x));
p.addOptional('flags', 's', @(x) ischar(x) && all(arrayfun(@(flagchar) any(valid_flags == flagchar), x)));
p.parse(needle, haystack, flags);
needle = p.Results.needle;
haystack = p.Results.haystack;
flags = p.Results.flags;

% Matching mode flags
substr = any(flags == 's');
regex = any(flags == 'r');
exact = any(flags == 'e');

% Modifier flags
case_sensitive = any(flags == 'c');
return_all = any(flags == 'a');

% Make sure inputs are cell strings
if ~iscellstr(needle); needle = {needle}; end
if ~iscellstr(haystack); haystack = {haystack}; end

% Figure out matching function
if substr
    if case_sensitive
        f = @(pattern, str) any(cellfun(@(s) ~isempty(strfind(s, pattern)), str));
    else
        f = @(pattern, str) any(cellfun(@(s) ~isempty(strfind(lower(s), lower(pattern))), str));
    end
elseif regex
    case_option = 'ignorecase'; if case_sensitive; case_option = 'matchcase'; end
    f = @(str, expressions) any(~cellfun('isempty', regexp(str, expressions, case_option)));
elseif exact
    if case_sensitive
        f = @(needle, haystacks) any(strcmp(needle, haystacks));
    else
        f = @(needle, haystacks) any(strcmpi(needle, haystacks));
    end
end

% Match
TF = false(size(needle));
for i = 1:numel(needle)
    % Returns true if needle i is in ANY haystack
    found = f(needle{i}, haystack);
    
    % Save result for needle i
    TF(i) = found;
    
    % Return as soon as we find needle
    if ~return_all && found
        TF = true;
        return
    end
end

if ~return_all
    TF = false;
end
end

