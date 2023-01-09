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

param0 = [0.5, 0.95, 0.0];
% lambda0 = zeros(size(y_ij, 1), 1);
data = y_ij;
data(y_ij < 0.02 | y_ij > 0.98) = nan;
lambda0 = nanmean(log2(data) - E_j(:)', 2);

options = optimset('Display', 'off', 'MaxFunEvals', 10000);
x = fminunc(@(x) err_func(y_ij, x, E_j, param0), lambda0, options);
lambda = fminsearch(@(x) err_func(y_ij, x, E_j, param0), x, options);
x = fminunc(@(x) err_func(y_ij, x(4:end), E_j, x(1:3)), [param0(:); lambda], options);
x = fminsearch(@(x) err_func(y_ij, x(4:end), E_j, x(1:3)), x, options);
param = abs(x(1:3)) + [0; 0; 1];
lambda = x(4:end);
end


function e = err_func(y_ij, lambda_i, E_j, param)
p_ij = lambda_i(:) + E_j(:)';
e = y_ij - trc_curve(p_ij, abs(param(:)) + [0; 0; 1]);
% e = mean(e(:).^2);

e0 = 0.01;
idx = abs(e) < e0;
e = e.^2 .* idx + (2 * e0 * abs(e) - e0^2) .* (~idx);
e = mean(e(:));
% e = mean(e(:) ./ max(abs(y_ij(:)), 1e-8));
end