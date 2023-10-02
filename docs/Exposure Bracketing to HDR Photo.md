# Fit Characteristic Curve

It is the code repository for [[亮度响应与 HDR 基础|this article]] or [this zhihu column](https://zhuanlan.zhihu.com/p/23981690).

tags: [[HDR]], [[color science]], [[math]], [[我的知乎专栏文章]]

## Exposure bracket

Exposure bracketing results in a set of images with varying lightness, each described by its EV (Exposure Value). The EV is determined by the shutter speed, aperture, and ISO. By selecting a pixel at the same location across the bracketed images, we observe a pixel sequence ranging from dark to bright. Different pixel locations yield different sequences. These sequences can be plotted on an EV vs. Pixel Value chart, as shown below:

![EV-value](img/sample_curve_iso100_R.png)

The blue, red, and yellow curves represent different pixel sequences. Observably, the pixel corresponding to the blue curve is the brightest, while the yellow curve corresponds to the darkest pixel. The absolute value on the x-axis is not significant, as it can be shifted arbitrarily.These curves can be interpreted as portions of the camera's response characteristic curve, shifted by different offsets along the x-axis. By adjusting these offsets appropriately, the curves converge to form a single curve, as illustrated below:

![curve_shift](img/sample_curve_iso100_R_merge.png)

The offset of a single curve segment needed to align with the total curve can be considered a measure of the pixel's *real intensity*, up to an arbitrary scale. For instance, the blue curve, representing the brightest pixel, requires the greatest positive offset, while the yellow curve, representing the darkest pixel, requires the smallest negative offset.

## Curve function

Our goal is to find offsets for each pixel that allow them to align on a smooth curve. The type of curve we need is somewhat arbitrary, provided it's smooth and can accurately represent the shape of the data. However, I've chosen to start with some basic knowledge about the camera ISP pipeline. Modern CMOS sensors tend to have a linear characteristic. A point with a real intensity, $I$, will yield a sensor value, $x$, that is proportional to $I$, i.e., $x = kI$. We'll disregard the color correction phase that the camera ISP performs. The camera then applies a non-linear transformation, often referred to as gamma, modeled as $y = x^\gamma$, where $y$ is the pixel value and $x$ is the sensor value.

Therefore, I begin with a function $f$ defined as follows:

$$
f(x) = \big(k \exp(x)\big)^\gamma = \exp(a x + b) ,
$$

where $x$ is EV, and thus $\exp(x)$ is the actual intensity. However, most cameras perform a more complex non-linear transformation than just a gamma exponentiation. Considering a *shoulder* characteristic, where the pixel value saturates as intensity approaches infinity, I select a composite function as follows:

$$
g(x) = s\big(1-c\exp\big(-f(x)\big)\big)=s\big(1-c\exp(-\exp(a x + b))\big) .
$$

Given that all curves are essentially the same but with a constant x-offset, we can safely ignore coefficient $b$:

$$
g(x) = s\big(1 - c\exp(-\exp(ax))\big) .
$$

## Optimization

Assume we have $n$ pixels with $m$ exposures, denoted by $y_{ij}$, where $i$ represents the pixels and $j$ the exposures. Our objective is to estimate the exposure offset $\lambda_i, i=1,2,\dots,n$ for each pixel, along with the curve parameters $s, c, a$.

We can reformulate this as an optimization problem:

$$
\min_{s,c,a,\lambda_i} \quad\quad L=\sum_{i,j}\big(y_{ij} - g(\lambda_i + E_j)\big)^2 
= \sum_{i,j} \big(y_{ij}-g(p_{ij})\big)^2 ,
$$

where $E_j$ represents the relative EV for the $j$th exposure, which are known constants, and $p_{ij}=\lambda_i + E_j$.

Clearly, this is not a convex problem, meaning we cannot guarantee a global minimum. However, we are likely to obtain a sufficiently good solution from a reasonable starting point, using an appropriate optimization method, such as `fminunc` or `fminsearch`.

Here is a resulting curve. The curves are vertically shifted for clarity.

![fit_curve](img/fit_rgb_curve.png)

## Exposure offset

With the estimated curve parameters $a, c, s$, we are now prepared to estimate the exposure offset $\lambda_i$ for *all* pixels in the image. Note that in the previous section when we estimated the curve parameters, we already obtained exposure offsets for the sampled $n$ pixels. However, due to computational efficiency, we can't consider all pixels simultaneously. We need to perform the estimation with the aid of a given characteristic curve, hence why we conduct it in a separate phase.

The inverse function for the characteristic curve is:

$$
g^{-1}(x)=-\log(-\log((1-x/s)/c))/a.
$$

For any image pixel value $y_{ij}$, we can obtain the corresponding EV value via this inverse characteristic curve by $p_{ij} = g^{-1}(y_{ij})$. As described in the previous section, it is composed of two parts, $p_{ij} = \lambda_i + E_j$. Since $E_j$ is known for every image in the sequence, we then obtain the estimated exposure offset by:

$$
\hat\lambda_i^{(j)} = g^{-1}(y_{ij}) - E_j .
$$

Ideally, all $\hat\lambda_i^{(j)}, j=1,2,\dots,m$ would be equal, but in reality, they are not. We select those pixel values that are in a proper range (not too bright or too dark), average them, and then we get the final estimation:

$$
\hat \lambda_i = \frac{1}{|M_i|}\sum_{j\in M_i}g^{-1}(y_{ij}) - E_j ,
$$

where $M_i$ is a set that $y_{ij}$ has a proper pixel value (e.g., in the range [0.05, 0.95]).
