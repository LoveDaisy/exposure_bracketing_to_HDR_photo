clear; close all; clc;

image_folder = '../dataset';
image_list = dir(sprintf('%s/*.jpg', image_folder));

%%
% Step 1. Read exposure parameters.
ev_list = read_bracket_exposure(image_folder, image_list);

%%
% Step 2. Register images (find transforms)
[tf_list, ref_idx] = register_images(image_folder, image_list, ev_list);

%%
% Step 3. Estimate curve parameters
curve_param = estimate_curve_param(image_folder, image_list, ev_list, 'Transforms', tf_list);

%%
% Step 4. Estimate all pixels
image_ev = estimate_image_ev(image_folder, image_list, curve_param, ev_list, 'Transforms', tf_list);

%%
figure(2); clf;
imshow(exp(image_ev/2.2) * 0.005^(1/2.2));
drawnow;

%%
rgb_param = colorspace.get_param('DisplayP3', 'linear');
yuv_param = colorspace.get_param('DisplayP3');

% Get linear image
lin_image = max(min(exp(image_ev) * 2, 1500), 0);

% Convert to non-linear with PQ inverse EOTF
non_lin_image = colorspace.pq_inverse_eotf(lin_image);

% Convert to YUV data
yuv_image = colorspace.rgb2ycbcr(non_lin_image, rgb_param, yuv_param);

% Save YUV data for encoding
img_size = size(image_ev);
img_name = image_list(1).name(1:end-4);
colorutil.write_yuv_rawdata(sprintf('%s_%dx%d_yuv420p10le_pq.yuv', img_name, img_size(2), img_size(1)), ...
    yuv_image, 10, 'tv', '420');
