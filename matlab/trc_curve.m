function y = trc_curve(x, param)
% DESCRIPTION
%   It returns the characteristic curve value for EV x. It has the form of:
%       y = max(min(s * (1 - c * exp(-exp(a * x))), 1), 0)
% INPUT
%   x:          Any shape array. The EV value.
%   param:      [a, s] param

a = param(1);
c = param(2);
s = param(3);
y = max(min(s * (1 - c * exp(-exp(a * x))), 1), 0);
end