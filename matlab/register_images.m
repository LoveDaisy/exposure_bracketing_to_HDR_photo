function [tf_list, ref_idx] = register_images(image_folder, image_list, ev_list, varargin)
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

[~, idx] = sort(ev_list(:, 1));
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

img_size = size(ref_img);
ref_mask = ref_img < 0.95;
moving_mask = moving_img < 0.95;

ref_img = colorspace.rgb_ungamma(ref_img);
moving_img = colorspace.rgb_ungamma(moving_img);

gaussian_detail_config = {'KernelSize', 0.003};
ref_img = get_gaussian_detail(ref_img, gaussian_detail_config{:});
moving_img = get_gaussian_detail(moving_img, gaussian_detail_config{:});

mt = 1000;
pts_0  = detectSURFFeatures(ref_img, 'metricthreshold', mt);
idx0 = max(floor(pts_0.Location), 1);
idx0 = ref_mask(sub2ind(img_size, idx0(:, 2), idx0(:, 1)));
pts_0 = pts_0(idx0);

pts_1  = detectSURFFeatures(moving_img, 'metricthreshold', mt);
idx1 = max(floor(pts_1.Location), 1);
idx1 = moving_mask(sub2ind(img_size, idx1(:, 2), idx1(:, 1)));
pts_1 = pts_1(idx1);

pts_num_list = [200, 500, 1000];
for i = 1:length(pts_num_list)
    n = pts_num_list(i);
    [features_0,  valid_pts_0]  = extractFeatures(ref_img,  pts_0.selectStrongest(n));
    [features_1,  valid_pts_1]  = extractFeatures(moving_img,  pts_1.selectStrongest(n));

    % Match base image and m3
    idx = matchFeatures(features_0, features_1, 'MatchThreshold', 2);
    matched_pts_0  = valid_pts_0(idx(:, 1));
    matched_pts_1  = valid_pts_1(idx(:, 2));

    if length(matched_pts_0) < 10 || length(matched_pts_1) < 10
        continue;
    end
    [tf, inlier1, inlier0] = estimateGeometricTransform(matched_pts_1, matched_pts_0, 'similarity');
    if length(inlier1) > 10
        break;
    end
end
if ~exist('tf', 'var') || length(inlier1) < 10
    tf = [];
    return;
end
if p.Results.ShowMatch
    showMatchedFeatures(ref_img,  moving_img, inlier0, inlier1);
end
end
