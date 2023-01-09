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
