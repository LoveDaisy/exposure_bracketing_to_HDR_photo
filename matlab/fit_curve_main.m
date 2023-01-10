clear; close all; clc;

image_folder = '../dataset';
image_list = dir(sprintf('%s/*.jpg', image_folder));
image_num = length(image_list);

img_size = [];

%%
% Step 1. Read exposure parameters.
E_j = read_bracket_exposure(image_folder, image_list);

%%
% Step 2. Register images (find transforms)
[~, idx] = sort(E_j);
reference_idx = idx(round((1 + length(idx)) / 2));
fprintf('Register images to #%d\n', reference_idx);

img_name = sprintf('%s/%s', image_folder, image_list(reference_idx).name);
fprintf('  reading %s\n', img_name)
img_ref = im2double(imread(img_name));
tf_store = cell(image_num, 1);
for i = 1:image_num
    if i == reference_idx
        tf_store{i} = [];
        continue;
    end
    img_name = sprintf('%s/%s', image_folder, image_list(i).name);
    fprintf('  reading %s\n', img_name)
    img = im2double(imread(img_name));
    
    tf = find_transform(img_ref, img);
    tf_store{i} = tf;
end
clear img_ref tf

%%
% Step 3. Estimate curve parameters
sample_num = 80;
sample_h = 2;
sample_pixel_store = nan(sample_num, 3, image_num);
param_store = zeros(3, 3);              % Each row [a, c, s] for a single channel (R/G/B)
lambda_store = zeros(sample_num, 3);    % Each column for a channel
for i = 1:image_num
    fprintf('Reading image %s (%d/%d)...\n', image_list(i).name, i, length(image_list));
    img_name = sprintf('%s/%s', image_folder, image_list(i).name);
    img_info = imfinfo(img_name);
    img = im2double(imread(img_name));
    if isempty(img_size)
        img_size = size(img);
        pix_idx = randsample(prod(img_size(1:2)), sample_num);
    end
    if ~isempty(tf_store{i})
        output_view = imref2d(img_size(1:2));
        img = imwarp(img, tf_store{i}, 'OutputView', output_view);
    end
    
    img = imfilter(img, ones(sample_h * 2 + 1) / (sample_h * 2 + 1)^2);     % Box filter
    img = reshape(img, [], 3);
    sample_pixel_store(:, :, i) = img(pix_idx, :);
end
clear i

% Fit curve
for ch = 1:3
    y_ij = reshape(sample_pixel_store(:, ch, :), sample_num, []);
    [param, lambda] = fit_trc_curve(y_ij, E_j);
    param_store(ch, :) = param;
    lambda_store(:, ch) = lambda(:);
end
clear lambda param ch

%%
figure(1); clf;
hold on;
ch_color = [217, 83, 25;
    46, 173, 88;
    0, 114, 189]/255;
for ch = 1:3
    plot_offset = (ch - 1) * 0.2;
    tmp_x = E_j(:) + lambda_store(:, ch)';
    tmp_y = reshape(sample_pixel_store(:, ch, :), sample_num, [])' + plot_offset;
    plot(tmp_x(:), tmp_y(:), '.', 'color', ch_color(ch, :));
    plot(-15:.1:10, trc_curve(-15:.1:10, param_store(ch, :)) + plot_offset, ...
        '-', 'linewidth', 1.5, 'color', ch_color(ch, :));
end
box on;
set(gca, 'ylim', [-.02, 1.42], 'xlim', [-12, 8], 'yscale', 'linear', 'fontsize', 12);
xlabel('Relative Intensity (EV)', 'fontsize', 15);
ylabel('Gray Scale (shifted)', 'fontsize', 15);
legend({'Empirical data', 'Fitted curve'}, 'fontsize', 12, 'location', 'northwest');
title('Characteristic Curve (RGB Channels)', 'fontsize', 16);
drawnow;

clear tmp_* ch plot_offset

%%
% Step 4. Estimate all pixels
image_ev = nan(img_size);

for h = 1:ceil(img_size(1)/2):img_size(1)
    for w = 1:ceil(img_size(2)/2):img_size(2)
        h1 = h; h2 = min(h + ceil(img_size(1) / 2) - 1, img_size(1));
        w1 = w; w2 = min(w + ceil(img_size(2) / 2) - 1, img_size(2));
        image_store = zeros(h2-h1+1, w2-w1+1, 3);   % Image is large. For memory saving.
        for i = 1:image_num
            fprintf('Reading image %s (%d/%d)...\n', image_list(i).name, i, length(image_list));
            img = im2double(imread(sprintf('%s/%s', image_folder, image_list(i).name)));
            if ~isempty(tf_store{i})
                output_view = imref2d(img_size(1:2));
                img = imwarp(img, tf_store{i}, 'OutputView', output_view);
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
    img = im2double(imread(sprintf('%s/%s', image_folder, image_list(reference_idx).name)));
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
