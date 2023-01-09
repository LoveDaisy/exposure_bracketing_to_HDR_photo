function img_norm = normalize_image(img, varargin)
p = inputParser;
p.addRequired('img', @(x) length(size(x)) == 2 || length(size(x)) == 3 && size(x, 3) == 3);
p.parse(img, varargin{:});
img_norm = adapthisteq(img);
end
