clear; close all; clc;

image_folder = '../dataset';
image_list = dir(sprintf('%s/*.jpg', image_folder));
image_num = length(image_list);

img_size = [];

%%
% Step 1. Estimate curve parameters
sample_num = 80;
sample_h = 2;
sample_pixel_store = nan(sample_num, 3, image_num);
E_j = zeros(image_num, 1);
param_store = zeros(3, 3);              % Each row [a, c, s] for a single channel (R/G/B)
lambda_store = zeros(sample_num, 3);    % Each column for a channel
for i = 1:image_num
    fprintf('Reading image %s (%d/%d)...\n', image_list(i).name, i, length(image_list));
    img_name = sprintf('%s/%s', image_folder, image_list(i).name);
    img_info = imfinfo(img_name);
    E_j(i) = log2(img_info.DigitalCamera.ISOSpeedRatings * img_info.DigitalCamera.ApertureValue * ...
        img_info.DigitalCamera.ExposureTime);
    img = im2double(imread(img_name));
    if isempty(img_size)
        img_size = size(img);
        pix_idx = randsample(prod(img_size(1:2)), sample_num);
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
% Step 2. Estimate all pixels
image_ev = nan(img_size);

for h = 1:ceil(img_size(1)/2):img_size(1)
    for w = 1:ceil(img_size(2)/2):img_size(2)
        h1 = h; h2 = min(h + ceil(img_size(1) / 2) - 1, img_size(1));
        w1 = w; w2 = min(w + ceil(img_size(2) / 2) - 1, img_size(2));
        image_store = zeros(h2-h1+1, w2-w1+1, 3);   % Image is large. For memory saving.
        for i = 1:image_num
            fprintf('Reading image %s (%d/%d)...\n', image_list(i).name, i, length(image_list));
            img = im2double(imread(sprintf('%s/%s', image_folder, image_list(i).name)));
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
clear data image_store img w1 w2 w h1 h2 h ch i

%%
figure(2); clf;
imshow(exp(image_ev/2.2) * 0.005^(1/2.2));
drawnow;
