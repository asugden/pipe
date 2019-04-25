function [residuals, t] = ellipse_residuals(x, y, params, t0, calcTheta)
%   David Brann, 2017
%   Calculate residuals for a fit to an ellipse 

    if nargin < 5, calcTheta = 1; end

    % %%%
    % TO DO
    % 1) Warp to circle so it's easier to find residuals, the warp back
    % SEE https://math.stackexchange.com/questions/619037/circle-affine-transformation
    % AND https://www.mathworks.com/matlabcentral/answers/35083-affine-transformation-that-takes-a-given-known-ellipse-and-maps-it-to-a-circle-with-diameter-equal
    % %%%

    % Unpack ellipse params
    theta = params(5);
    ctheta = cos(theta);
    stheta = sin(theta);

    xc = params(1);
    yc = params(2);
    a = params(3);
    b = params(4);

    residuals = zeros(size(x));

    % Initial guess for theta
    if nargin < 4 || (isempty(t0) && calcTheta) || calcTheta
        t0 = atan2(y - yc, x - xc) - theta;

        % Display off to suppress warnings about maxiter
        options = optimset('MaxIter', 50);
        t = zeros(size(x));
        for i = 1:length(x)
            xi = x(i);
            yi = y(i);

            % Optimize LS error of function to find closest theta
            myfunc = @(t) ((xc + a * ctheta * cos(t) - b * stheta * sin(t)) - xi)^2 + ...
                ((yc + a * stheta * cos(t) + b * ctheta * sin(t)) - yi)^2;

            %     residuals_t0(i) = sqrt(myfunc(t0(i)));
            %     x = lsqcurvefit(myfunc,t0,xi,yi)
            [t(i), ~] = fminsearch(myfunc,t0(i),options);

            % these are slower
            %     x = fmincon(myfunc,t0(i),[],[],[],[],-pi,pi);
            %     x = fminbnd(myfunc,t0(i)-pi,t0(i)+pi);
            residuals(i) = sqrt(myfunc(t(i)));
        end

    else
        t = atan2(y - yc, x - xc) - theta;
        % Calculate residuals using provided theta
        residuals = sqrt(((xc + a * ctheta .* cos(t) - b * stheta .* sin(t)) - x).^2 + ...
            ((yc + a * stheta .* cos(t) + b * ctheta .* sin(t)) - y).^2);
    end

end




