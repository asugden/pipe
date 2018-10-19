function [x, y, varargout] = dffhistogram(dff)
    dff = dff - median(dff);
    dff = dff/max(dff);
    
    nBins = int32(length(dff)/3);
    
    % Get histogram of trace
    [y, x] = histcounts(dff, nBins);
    x = x(1:nBins)';
    
    % Scale so that the integral = 1. This allows us to fit using PDFs
    y = (y/sum(y*(x(2)-x(1))))';
    
    if nargout > 2
        varargout{1} = dff;
    end
end