function E_j = read_bracket_exposure(image_folder, image_list, varargin)
% DESCRIPTION
%   Read exposure values of `image_list`
% SYNTEX
%   E_j = read_bracket_exposure(image_folder, image_list)
%   E_j = read_bracket_exposure(..., Name, Value, ...)
% INPUT
%   image_folder:       A string
%   image_list:         n-length struct array of file. Generally it is returned by `dir` function.
% OPTION
%   'Verbose':          Logical, default is true.
% OUTPUT
%   E_j:                n*1 array, where n is the length of `image_list`. It stores
%                       exposure value of each image.

p = inputParser;
p.addRequired('image_folder', @(x)ischar(x));
p.addRequired('image_list', @(x)isvector(x) && isfield(x, 'name'));
p.addParameter('Verbose', true, @(x)islogical(x) && isscalar(x));
p.parse(image_folder, image_list, varargin{:});

image_num = length(image_list);
E_j = zeros(image_num, 1);

if p.Results.Verbose
    fprintf('Read exposure settings...\n');
end
for i = 1:image_num
    img_name = sprintf('%s/%s', image_folder, image_list(i).name);
    if p.Results.Verbose
        fprintf('  reading %s\n', img_name)
    end
    img_info = imfinfo(img_name);
    curr_ev = log2(img_info.DigitalCamera.ISOSpeedRatings * img_info.DigitalCamera.ApertureValue * ...
        img_info.DigitalCamera.ExposureTime);
    ev_bias = regexp(image_list(i).name, '([+-]?[0-9.]+)EV', 'tokens');
    if ~isempty(ev_bias)
        curr_ev = curr_ev + str2double(ev_bias{1}{1});
    end
    E_j(i) = curr_ev;
end
end