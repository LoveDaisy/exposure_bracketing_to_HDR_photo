clear; close all; clc;

image_folder = '../dataset';
image_list = dir(sprintf('%s/*.jpg', image_folder));
image_num = length(image_list);

%%
% Step 1. Read exposure parameters.
E_j = read_bracket_exposure(image_folder, image_list);

%%
% Step 2. Register images (find transforms)
[tf_list, ref_idx] = register_images(image_folder, image_list, E_j);

%%
% Step 3. Estimate curve parameters
param_store = estimate_curve_param(image_folder, image_list, E_j, 'Transforms', tf_list);

%%
% Step 4. Estimate all pixels
img_info = imfinfo(sprintf('%s/%s', image_folder, image_list(ref_idx).name));
img_size = [img_info.Height, img_info.Width, img_info.NumberOfSamples];
image_ev = nan(img_size);

for h = 1:ceil(img_size(1)/2):img_size(1)
    for w = 1:ceil(img_size(2)/2):img_size(2)
        h1 = h; h2 = min(h + ceil(img_size(1) / 2) - 1, img_size(1));
        w1 = w; w2 = min(w + ceil(img_size(2) / 2) - 1, img_size(2));
        image_store = zeros(h2-h1+1, w2-w1+1, 3);   % Image is large. For memory saving.
        for i = 1:image_num
            fprintf('Reading image %s (%d/%d)...\n', image_list(i).name, i, length(image_list));
            img = im2double(imread(sprintf('%s/%s', image_folder, image_list(i).name)));
            if ~isempty(tf_list{i})
                output_view = imref2d(img_size(1:2));
                img = imwarp(img, tf_list{i}, 'OutputView', output_view);
            end
            img = img(h1:h2, w1:w2, :);
            image_store(:, :, :, i) = img;
        end
        for ch = 1:3
            data = image_store(:, :, ch, :);
            data(data < 0.1 | data > 0.98) = nan;
            data = inverse_trc_curve(data, param_store(ch, :));
            data(isinf(data)) = nan;
            data = data + reshape(E_j, [1, 1, 1, image_num]);
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
    
    clear img_black img_white
end
clear data image_store img w1 w2 w h1 h2 h ch i nan_idx

%%
figure(2); clf;
imshow(exp(image_ev/2.2) * 0.005^(1/2.2));
drawnow;

%%
% Linear image
rgb_param = colorspace.get_param('DisplayP3', 'linear');
yuv_param = colorspace.get_param('DisplayP3');
lin_image = max(min(exp(image_ev) * 2, 1500), 0);
non_lin_image = colorspace.pq_inverse_eotf(lin_image);
yuv_image = colorspace.rgb2ycbcr(non_lin_image, rgb_param, yuv_param);

colorutil.write_yuv_rawdata('test_4032x3024_yuv420p10le_pq.yuv', yuv_image, 10, 'tv', '420');
% colorutil.write_yuv_rawdata('test_3024x4032_yuv420p10le_pq.yuv', yuv_image, 10, 'tv', '420');
