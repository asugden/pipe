function [noise_, varargout] = dffnoise(dff)
% GETDFFNOISE Calculate the noise within a cell dF/F0 using the combination
% of a best-fit chi-square probability density function (PDF) and a normal 
% PDF. Returns the mean and standard deviation of the noise. Optionally 
% returns
    % mu, sigma, noise, fitdata = getdffnoise(x, y)
    % mu, sigma, noise, k, scale, xoffset = getdffnoise(x, y)
    % mu, sigma, noise, k, scale, xoffset, fitdata = getdffnoise(x, y)
% where mu is normal mean, sigma is normal stdev, noise is the fraction of
% the dFF that is noise, fitdata is the best fit to x, k is the parameter
% of the chi-square PDF, scale is a scaling parameter for the height of the
% chi-square PDF, and xoffset is the position where x = 0 for a traditional
% chi-square PDF.

    [xd, yd] = pipe.proc.dffhistogram(dff);
    
    % And smooth to find the peak
    ys = pipe.proc.smooth(yd, length(yd)/40.0);
    [maxy, maxi] = max(ys);
    mu_ = xd(maxi);
        
    % Calculate the fit
    options = optimset('display', 'off');
    fun = @(x, xdata)normpdf(xdata, mu_, x(1))*x(2);
    f1 = lsqcurvefit(fun, [0.08, 0.5], xd(1:maxi), yd(1:maxi), [0.0, 0.0], [10.0, 1.0], options);
    
    sigma_ = f1(1);
    noise_ = f1(2);
        
    % Return the correct number of outputs
    if nargout > 1
        varargout{1} = mu_;
        varargout{2} = sigma_; 
    end
    if nargout > 3
        fun = @(x, xdata)pipe.proc.chinorm(xd, mu_, sigma_, x(1), x(2), x(3), noise_);
        f2 = lsqcurvefit(fun, [3, 3, 0.2], xd, yd, [0.0, 0.0, -999999], [999999 999999 999999], options);

        k_ = f2(1);
        scale_ = f2(2);
        xoffset_ = f2(3);
        
        varargout{3} = k_;
        varargout{4} = scale_;
        varargout{5} = xoffset_;
    end
end

