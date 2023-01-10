function image_ev = estimate_image_ev(image_folder, image_list, curve_param, ev_list, varargin)
% DESCRIPTION
%   This function estimates image EV.
% SYNTAX
%   image_ev = estimate_image_ev(image_folder, image_list)
%   image_ev = estimate_image_ev(..., Name, Value, ...)
% INPUT
%   image_folder:       A string
%   image_list:         n-length struct array of file. Generally it is returned by `dir` function.
%   curve_param:        3*3 array. Parameters of curve.
%   ev_list:            n-length array. EVs for each image in `image_list`
% OPTION
%   'Verbose':          Logical, default is true.
%   'Transforms':       n*1 cell array of `tf` struct, default is empty cell array.
%   'RefIdx':           Index for exposure reference image. Default is floor((1 + length(image_list)) / 2).
% OUTPUT
%   image_ev:           The same size of input image. The EV of estimated real intensity.
%                       Real intensity is proportional to exp(ev), up to a constant scale.

p = inputParser;
p.addRequired('image_folder', @(x)ischar(x));
p.addRequired('image_list', @(x)isvector(x) && isfield(x, 'name'));
p.addRequired('curve_param', @(x)isnumeric(x) && length(size(x)) == 2 && all(size(x) == [3, 3]));
p.addRequired('ev_list', @(x)isnumeric(x) && isvector(x) && length(x) == length(image_list));
p.addParameter('Verbose', true, @(x)islogical(x) && isscalar(x));
p.addParameter('Transforms', {}, @(x)isvector(x) && iscell(x));
p.addParameter('RefIdx', -1, @(x)isnumeric(x) && isscalar(x));
p.parse(image_folder, image_list, curve_param, ev_list, varargin{:});

image_num = length(image_list);
if p.Results.RefIdx < 0
    ref_idx = floor((1 + image_num) / 2);
else
    ref_idx = p.Results.RefIdx;
end
img_info = imfinfo(sprintf('%s/%s', image_folder, image_list(ref_idx).name));
img_size = [img_info.Height, img_info.Width, img_info.NumberOfSamples];
image_ev = nan(img_size);

if p.Results.Verbose
    fprintf('Estimating image EV...\n');
    fprintf('For memory saving, all images will be read multiple times. It takes time.\n')
end

round = 0;
for h = 1:ceil(img_size(1)/2):img_size(1)
    for w = 1:ceil(img_size(2)/2):img_size(2)
        h1 = h; h2 = min(h + ceil(img_size(1) / 2) - 1, img_size(1));
        w1 = w; w2 = min(w + ceil(img_size(2) / 2) - 1, img_size(2));
        image_store = zeros(h2-h1+1, w2-w1+1, 3);   % Image is large. For memory saving.
        round = round + 1;
        if p.Results.Verbose
            fprintf('  round %d\n', round);
        end
        for i = 1:image_num
            fprintf('  reading image %s (%d/%d)...\n', image_list(i).name, i, length(image_list));
            img = im2double(imread(sprintf('%s/%s', image_folder, image_list(i).name)));
            if ~isempty(p.Results.Transforms) && ~isempty(p.Results.Transforms{i})
                output_view = imref2d(img_size(1:2));
                img = imwarp(img, p.Results.Transforms{i}, 'OutputView', output_view);
            end
            img = img(h1:h2, w1:w2, :);
            image_store(:, :, :, i) = img;
        end
        for ch = 1:3
            data = image_store(:, :, ch, :);
            data(data < 0.05 | data > 0.98) = nan;
            data = inverse_trc_curve(data, curve_param(ch, :));
            data(isinf(data)) = nan;
            data = data + reshape(ev_list, [1, 1, 1, image_num]);
            image_ev(h1:h2, w1:w2, ch) = -nanmean(data, 4);
        end
    end
end

nan_idx = isnan(image_ev);
if any(nan_idx(:))
    img = im2double(imread(sprintf('%s/%s', image_folder, image_list(ref_idx).name)));
    img = rgb2gray(img);
    
    img_black = nanmin(image_ev(:)) - 1;
    img_white = nanmax(image_ev(:)) + 1;
    
    image_ev(nan_idx & img > 0.5) = img_white;
    image_ev(nan_idx & img < 0.5) = img_black;
end
end