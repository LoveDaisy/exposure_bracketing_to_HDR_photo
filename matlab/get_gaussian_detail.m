function img_enh = get_gaussian_detail(img, varargin)
p = inputParser;
p.addRequired('img', @(x) length(size(x)) == 2 || length(size(x)) == 3 && size(x, 3) == 3);
p.addParameter('KernelSize', 0.05, @(x) isnumeric(x) && x > 0 && x <= 1);
p.parse(img, varargin{:});

if length(size(img)) == 3
    img_gray = rgb2gray(img);
else
    img_gray = img;
end
[hei, wid] = size(img_gray);
k = p.Results.KernelSize * norm([hei, wid]);
img_enh = img_gray - imgaussfilt(img_gray, k);
img_enh = normalize_image(img_enh);
end
