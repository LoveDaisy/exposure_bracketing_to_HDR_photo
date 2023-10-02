clear; close all; clc;

image_folder = '../dataset/IMG_8021';
image_list = dir(sprintf('%s/*.jpg', image_folder));

%%
% Step 1. Read exposure parameters.
ev_list = read_bracket_exposure(image_folder, image_list);

%%
% Step 2. Register images (find transforms)
[tf_list, ref_idx] = register_images(image_folder, image_list, ev_list);

%%
% Step 3. Estimate curve parameters
curve_param = estimate_curve_param(image_folder, image_list, ev_list(:, 1), ...
    'Transforms', tf_list, 'ChannelShare', false);

%%
% Step 4. Estimate all pixels
image_ev = estimate_image_ev(image_folder, image_list, curve_param, ev_list(:, 1), 'Transforms', tf_list);
img_size = size(image_ev);
img_size = img_size(1:2);
img_size_mul = floor(img_size / 16) * 16;
image_ev = image_ev(floor((img_size(1) - img_size_mul(1)) / 2)+(1:img_size_mul(1)), ...
    floor((img_size(2) - img_size_mul(2)) / 2)+(1:img_size_mul(2)), :);

%%
figure(2); clf;
imshow(exp(image_ev/2.2) * 0.005^(1/2.2), 'InitialMagnification', 'fit');
drawnow;

%%
rgb_param = colorspace.get_param('2020', 'linear');
yuv_param = colorspace.get_param('2020');
tf = 'hlg';

% Get linear image
lin_image = exp(image_ev .* reshape([1, 1, 1] * 1, [1, 1, 3])) .* ...
    reshape(16 * [1, 1, 1], [1, 1, 3]);

% Simply roll off
lin_image = lin_image - (1 - exp(-lin_image / 4000.0)) .* lin_image .* reshape([1, 1, 1] * 0.8, [1, 1, 3]);

% Clamp
lin_image = min(lin_image, 9000);

% Convert to non-linear with PQ inverse EOTF or HLG OETF
if strcmpi(tf, 'pq')
    non_lin_image = colorspace.pq_inverse_eotf(lin_image);
else
    non_lin_image = colorspace.hlg_oetf(min(lin_image / 2000, 1));
end
figure(3);
colorvis.parade_diagram(non_lin_image);

% Convert to YUV data
yuv_image = colorspace.rgb2ycbcr(non_lin_image, rgb_param, yuv_param);

% Save YUV data for encoding
img_size = size(image_ev);
img_name = image_list(1).name(1:end-4);
colorutil.write_yuv_rawdata(sprintf('%s_%dx%d_yuv420p10le_%s.yuv', img_name, img_size_mul(2), img_size_mul(1), tf), ...
    yuv_image, 10, 'tv', '420');
