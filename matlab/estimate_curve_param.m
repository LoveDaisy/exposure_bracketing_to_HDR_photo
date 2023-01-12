function param_store = estimate_curve_param(image_folder, image_list, E_j, varargin)
% DESCRIPTION
%   Estimate curve parameters
% SYNTAX
%   param =  estimate_curve_param(image_folder, image_list)
% INPUT
%   image_folder:       A string
%   image_list:         n-length struct array of file. Generally it is returned by `dir` function.
%   E_j:                n*1 array, where n is the length of `image_list`. It stores
%                       exposure value of each image.
% OPTION
%   'Verbose':          Logical, default is true.
%   'DisplayCurve':     Logical, default is true.
%   'Transforms':       n*1 cell array of `tf` struct.
% OUTPUT
%   param_store:        3*3 array. Each row [a, c, s] for a single channel (R/G/B)

p = inputParser;
p.addRequired('image_folder', @(x)ischar(x));
p.addRequired('image_list', @(x)isvector(x) && isfield(x, 'name'));
p.addParameter('Verbose', true, @(x)islogical(x) && isscalar(x));
p.addParameter('DisplayCurve', true, @(x)islogical(x) && isscalar(x));
p.addParameter('Transforms', {}, @(x)isvector(x) && iscell(x));
p.parse(image_folder, image_list, varargin{:});

image_num = length(image_list);
img_size = [];

sample_num = 80;
sample_h = 2;
sample_pixel_store = nan(sample_num, 3, image_num);
param_store = zeros(3, 3);              % Each row [a, c, s] for a single channel (R/G/B)
lambda_store = zeros(sample_num, 3);    % Each column for a channel

if p.Results.Verbose
    fprintf('Estimating curve parameters...\n');
end
for i = 1:image_num
    if p.Results.Verbose
        fprintf('  reading image %s (%d/%d)...\n', image_list(i).name, i, length(image_list));
    end
    img_name = sprintf('%s/%s', image_folder, image_list(i).name);
    img = im2double(imread(img_name));
    if isempty(img_size)
        img_size = size(img);
        dx = floor(img_size(2) / 8);
        dy = floor(img_size(1) / 10);
        [xx, yy] = meshgrid(floor((1 + dx) / 2):dx:img_size(2), floor((1 + dy) / 2):dy:img_size(1));
        pix_idx = sub2ind(img_size(1:2), yy(:), xx(:));
    end
    if ~isempty(p.Results.Transforms) && ~isempty(p.Results.Transforms{i})
        output_view = imref2d(img_size(1:2));
        img = imwarp(img, p.Results.Transforms{i}, 'OutputView', output_view);
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
if p.Results.Verbose
    fprintf('Param of R: %.4f, %.4f, %.4f\n', param_store(1, 1), param_store(1, 2), param_store(1, 3));
    fprintf('Param of G: %.4f, %.4f, %.4f\n', param_store(2, 1), param_store(2, 2), param_store(2, 3));
    fprintf('Param of B: %.4f, %.4f, %.4f\n', param_store(3, 1), param_store(3, 2), param_store(3, 3));
end

if ~p.Results.DisplayCurve
    return;
end
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
end


function [param, lambda] = fit_trc_curve(y_ij, E_j)
% DESCRIPTION
%   It finds best fit to characteristic curve. See trc_curve() for detail.
% SYNTAX
%   param = fit_trc_curve(y_ij)
% INPUT
%   y_ij:           m*n array. each row is a pixel and column is an exposure.
%   E_j:            n-length vector. Relative EV for each exposure.
% OUTPUT
%   param:          [a, c, s] param.

param0 = [0.5, 1, 0.04];
data = y_ij;
data(y_ij < 0.01 | y_ij > 1) = nan;
lambda0 = nanmean(log2(data) - E_j(:)', 2);

options = optimset('Display', 'off', 'MaxFunEvals', 10000);
x = fminunc(@(x) err_func(y_ij, x, E_j, param0), lambda0, options);
lambda = fminsearch(@(x) err_func(y_ij, x, E_j, param0), x, options);
x = fminunc(@(x) err_func(y_ij, x(4:end), E_j, x(1:3)), [param0(:); lambda], options);
x = fminsearch(@(x) err_func(y_ij, x(4:end), E_j, x(1:3)), x, options);
param = abs(x(1:3)) + [0; 0; 0.95];
lambda = x(4:end);
end


function e = err_func(y_ij, lambda_i, E_j, param)
p_ij = lambda_i(:) + E_j(:)';
e = y_ij - trc_curve(p_ij, abs(param(:)) + [0; 0; 0.95]);

e0 = 0.05;
idx = abs(e) < e0;
e = e.^2 .* idx + (2 * e0 * abs(e) - e0^2) .* (~idx);
e = mean(e(:));
end