function cellsort = neuropil_correlation(cellsort)
% NEUROPIL_CORRELATION If the neuropil signal and the raw signal are highly
%   correlated then instead of subtracting the neuropil and getting no 
%   signal - just use the raw
    threshold = 0.99;
    rawrois = [];
    
    for i = 1:length(cellsort)
        correlation = corrcoef(cellsort(i).timecourse.raw, cellsort(i).timecourse.neuropil);
        correlation = correlation(1, 2);
        if correlation > threshold
            cellsort(i).timecourse.subtracted = cellsort(i).timecourse.raw;
            rawrois = [rawrois i];
        end
    end
    
    if ~isempty(rawrois)
        warning(['ROI number ' num2str(rawrois) ' has parts of ROI in neuropil so just using raw instead of subtracted'])
    end
end