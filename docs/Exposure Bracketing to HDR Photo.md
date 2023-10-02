# Fit Characteristic Curve

It is the code repository for [[亮度响应与 HDR 基础|this article]] or [this zhihu column](https://zhuanlan.zhihu.com/p/23981690).

tags: [[HDR]], [[color science]], [[math]], [[我的知乎专栏文章]]

## Exposure bracket

If we take exposure bracket images, we get a set of images. The lightness of an image is described by EV (Exposure Value), which is related to the shutter speed, the aperture, and the ISO. If we pick up a pixel at the same location of an image through the bracket, we will get a pixel sequence from dark to bright. Different pixel locations will result different sequences. Plot them on a EV vs. pixle value chart as follows:

![EV-value](img/sample_curve_iso100_R.png)

The blue, red, yellow curves are different pixel sequences. Clearly, the pixel corresponding to the blue curve is the brightest, and that of the yellow one is the darkest. The absolute value of x-axis is not important. They can be shifted arbitrary.

These curves can be regarded as part of the response characteristic curve of the camera, shifting by different offsets along x axis. If we shift them back with right amout of offsets, they will meet each other and form a single curve. It is shown as follows:

![curve_shift](img/sample_curve_iso100_R_merge.png)

The offset of a single curve segment that is needed to fit on the total curve can be regarded as a kind of *real intensity* of this pixel up to an arbitrary scale. For example, we know that the blue curve corresponds to the brightest pixel and yellow one corresponds to the darkest, as well it is the greatest offset (is positive here) the blue line need, and the smallest offset (is negative here) the yellow one need.

## Curve function

Our target is to find offsets for each pixel, so that they can meet each other on a smooth curve. What kind of curve do we need? It is quite random, as long as the curve is smooth and can describe the correct shape. Even so, I would like to start from some basic information of camera ISP pipeline. The modern CMOS sensor is quite linear. A point with real intensity $I$, will result a sensor value $x$ which is proportion to $I$, i.e. $x = k I$. We ignore the color correction phase that camera ISP will do. Then camera make a non-linear transform, which is often called gamma. It is often modeled as $y = x^\gamma$, where $y$ is the pixel value and $x$ is the sensor value.

So, I start from a function $f$ as follows:

$$
f(x) = \big(k \exp(x)\big)^\gamma = \exp(a x + b) ,
$$

where $x$ is EV, thus $\exp(x)$ is the real real intensity. However the non-linear transform of most camera is more complicated than just a gamma exponential. Consider a *shoulder* character, that pixel value gets saturated when intensity goes infinity. I choose a composite function as follows:

$$
g(x) = s\big(1-c\exp\big(-f(x)\big)\big)=s\big(1-c\exp(-\exp(a x + b))\big) .
$$

Consider all curves are considered the same up to a constant x offset, so we can ignore coefficent $b$ here savely,

$$
g(x) = s\big(1 - c\exp(-\exp(ax))\big) .
$$

## Optimization

Now, say that we have $n$ pixels with $m$ exposures, whose values are $y_{ij}$, where $i$ indicates pixels and $j$ indicates exposures. Our goal is to estimate every exposure offset $\lambda_i, i=1,2,\dots,n$ for each pixel, as well as curve parameters $s, c, a$.

We can formulate this question into an optimization problem:

$$
\min_{s,c,a,\lambda_i} \quad\quad L=\sum_{i,j}\big(y_{ij} - g(\lambda_i + E_j)\big)^2 
= \sum_{i,j} \big(y_{ij}-g(p_{ij})\big)^2 ,
$$

where $E_j$ is the relative EV for $j$th exposure, which are known constants, and $p_{ij}=\lambda_i + E_j$.

Clearly it is not a convex problem, which means we cannot guarantee global minimum. However we are probably to get a good enough solution from a reasonable starting point, with proper optimization method, such as `fminunc` or `fminsearch`.

Here is a result. Curves are shifted vertically for clarity.

![fit_curve](img/fit_rgb_curve.png)

## Exposure offset

With curve parameters $a, c, s$ estimated, we now are ready to estimate exposure offset $\lambda_i$ for *all* pixels in the image. Note that in the above section when we estimate curve parameters, we have already got exposure offsets for sampled $n$ pixels. However, for computation saving, we cannot take all pixels into account. We need to do the estimation with the help of a given characteristic curve. That's why we do it in a seperate phase.

The inverse function for the characteristic curve is:

$$
g^{-1}(x)=-\log(-\log((1-x/s)/c))/a.
$$

For any image pixel value $y_{ij}$, we can get corresponding EV value via this inverse characteristic curve by $p_{ij} = g^{-1}(y_{ij})$. As described in above section, it is composed with two part, $p_{ij} = \lambda_i + E_j$. Since $E_j$ is known for every image in the sequence, we then get the estimated exposure offset by:

$$
\hat\lambda_i^{(j)} = g^{-1}(y_{ij}) - E_j .
$$

Ideally, all $\hat\lambda_i^{(j)}, j=1,2,\dots,m$ are equal, but in fact they are not. We choose those pixel values are in a proper range, which means not too bright nor too dark, and average them, then we get the final estimation:

$$
\hat \lambda_i = \frac{1}{|M_i|}\sum_{j\in M_i}g^{-1}(y_{ij}) - E_j ,
$$

where $M_i$ is a set that $y_{ij}$ has proper pixel value (say in range [0.05, 0.95]).
