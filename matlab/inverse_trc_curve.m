function y = inverse_trc_curve(x, param)
% DESCRIPTION
%   It returns the inverse characteristic curve value for gray level x. It has the form of:
%       y = -log(-log(max(1 - x/s, 0)/c))/a
% INPUT
%   x:          Any shape array. The gray level of image, range in [0, 1]
%   param:      [a, c, s] param

a = param(1);
c = param(2);
s = param(3);
x = min(x, s);
y = -log(-log((1 - x/s)/c))/a;
end