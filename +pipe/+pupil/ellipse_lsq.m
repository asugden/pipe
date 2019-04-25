function [params, xy] = ellipse_lsq(epx, epy, bigA)
% fit Ellipse with least-squares algorithm
%%
% http://autotrace.sourceforge.net/WSCG98.pdf
% http://mathworld.wolfram.com/Ellipse.html
% https://github.com/scikit-image/scikit-image/blob/master/skimage/measure/fit.py#L380
if nargin < 3
    bigA = false;
end

D1 = [epx .* epx; epx .* epy; epy .* epy]';
D2 = [epx; epy; ones(size(epx))]';
S1 = D1'*D1;
S2 = D1'*D2;
S3 = D2'*D2;

%         # Constraint matrix [eqn. 18]
C = zeros(6);
C(1,3) = 2; C(2,2) = -1; C(3,1) = 2;
C1 = zeros(3);
C1(1,3) = 2; C1(2,2) = -1; C1(3,1) = 2;

if rcond(C1) < 1e-17 || rcond(S3) < 1e-17
    params = [];
    xy = [];
    return;
end

% Added to prevent warnings
M = inv(C1)\(S1 - (S2/S3)*S2');
[evec, ~] = eig(M);

cond = 4 * evec(1,:) .* evec(3,:) - evec(2,:).^2;
a1 = evec(:, cond > 0);

if length(a1) < 3
    params = [];
    xy = [];
    return;
end

a = a1(1); b = a1(2); c = a1(3);



a2 = -inv(S3)*S2'*a1;
d = a2(1); f = a2(2); g = a2(3);

b = b/2;
d = d/2;
f = f/2;

x0 = (c * d - b * f) / (b^2 - a * c);
y0 = (a * f - b * d) / (b^2 - a * c);

numerator = a*f^2 + c*d^2 + g*b^2 - 2*b*d*f - a*c*g;
term = sqrt((a-c)^2 + 4 * b^2);
denom1 = (b^2 - a*c) * (term - (a + c));
denom2 = (b^2 - a*c) * (- term - (a + c));
width = sqrt(2 * numerator / denom1);
height = sqrt(2 * numerator / denom2);
phi = 0.5 * atan((2*b)/(a-c));

%  ax^2+2bxy+cy^2+2dx+2fy+g=0
% TODO: CHECK TO MAKE SURE THIS WORKS FOR ALL CASES
% decide whether to adjust long axis
% alternatively always make a positive/the long axis
if bigA
    %set width to be the larger one
    if height > width
        width = width + height;
        height = width - height;
        width = width - height;
    end
else
    % fix orientation when vertical
    if a > c
        phi = phi + 0.5 * pi;
    end
end

params = [x0 y0 width height phi];

% params = struct();
% params.height = height;
% params.width = width;
% params.phi = phi;
% params.x0 = x0;
% params.y0 = y0;

if nargout > 1
    %generate ellipse
    t = linspace(0, 2*pi, 50);
    
    ct = cos(t);
    st = sin(t);
    ctheta = cos(phi);
    stheta = sin(phi);
    
    x = x0 + width * ctheta * ct - height * stheta * st;
    y = y0 + width * stheta * ct + height * ctheta * st;
    xy = [x; y];
end
