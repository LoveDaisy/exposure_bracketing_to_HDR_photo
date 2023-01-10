function [tf_list, ref_idx] = register_images(image_folder, image_list, E_j, varargin)
% DESCRIPTION
%   Register images, and find out transforms between each image and reference image.
% SYNTAX
%   [tf_list, ref_idx] = register_images(image_list)
%   [tf_list, ref_idx] = register_images(..., Name, Value, ...)
% INPUT
%   image_folder:       A string
%   image_list:         n-length struct array of file. Generally it is returned by `dir` function.
%   E_j:                n-length double. Exposure values of `image_list`.
% OPTION
%   'Verbose':          Logical, default is true.
% OUTPUT
%   tf_list:            n*1 cell array of `tf` struct.
%   ref_idx:            Index of image in `image_list` used as reference image.

p = inputParser;
p.addRequired('image_folder', @(x)ischar(x));
p.addRequired('image_list', @(x)isvector(x) && isfield(x, 'name'));
p.addParameter('Verbose', true, @(x)islogical(x) && isscalar(x));
p.parse(image_folder, image_list, varargin{:});

image_num = length(image_list);

[~, idx] = sort(E_j);
ref_idx = idx(round((1 + length(idx)) / 2));
if p.Results.Verbose
    fprintf('Register images to #%d\n', ref_idx);
end

img_name = sprintf('%s/%s', image_folder, image_list(ref_idx).name);
if p.Results.Verbose
    fprintf('  reading %s\n', img_name)
end
img_ref = im2double(imread(img_name));
tf_list = cell(image_num, 1);
for i = 1:image_num
    if i == ref_idx
        tf_list{i} = [];
        continue;
    end
    img_name = sprintf('%s/%s', image_folder, image_list(i).name);
    if p.Results.Verbose
        fprintf('  reading %s\n', img_name)
    end
    img = im2double(imread(img_name));
    
    tf = find_transform(img_ref, img);
    tf_list{i} = tf;
end
end


function tf = find_transform(ref_img, moving_img, varargin)
p = inputParser();
p.addParameter('ShowMatch', false, @(x) islogical(x) && isscalar(x));
p.parse(varargin{:});

gaussian_detail_config = {'KernelSize', 0.003};
ref_img = get_gaussian_detail(ref_img, gaussian_detail_config{:});
moving_img = get_gaussian_detail(moving_img, gaussian_detail_config{:});

mt = 1500;
pts_0  = detectSURFFeatures(ref_img, 'metricthreshold', mt);
pts_1  = detectSURFFeatures(moving_img, 'metricthreshold', mt);
[features_0,  valid_pts_0]  = extractFeatures(ref_img,  pts_0);
[features_1,  valid_pts_1]  = extractFeatures(moving_img,  pts_1);

% Match base image and m3
idx = matchFeatures(features_0, features_1);
matched_pts_0  = valid_pts_0(idx(:, 1));
matched_pts_1  = valid_pts_1(idx(:, 2));

if length(matched_pts_0) < 10 || length(matched_pts_1) < 10
    tf = [];
    return;
end
[tf, inlier1, inlier0] = estimateGeometricTransform(matched_pts_1, matched_pts_0, 'similarity');
if p.Results.ShowMatch
    showMatchedFeatures(ref_img,  moving_img, inlier0, inlier1);
end
end
