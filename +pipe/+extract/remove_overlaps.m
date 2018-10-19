function [sortorder included] = remove_overlaps(traces, masks, sortorder, overlap, ccorr)
% ELIMINATENMFOVERLAPS Removes overlapping ROIs with high
%   cross-correlations (defined by ccorr)

    % Generate masks from sparse matrix
    nrois = length(sortorder);
    redundant = logical(zeros(1, length(sortorder)));
    for i = 1:nrois
        for j = i+1:nrois
            if ~redundant(i) && ~redundant(j)
                t1 = sortorder(i);
                t2 = sortorder(j);

                sum1 = sum(sum(masks(:, :, t1)));
                sum2 = sum(sum(masks(:, :, t2)));

                if sum1 > 0 && sum2 > 0
                    sumcomb = sum(sum(and(masks(:, :, t1), masks(:, :, t2))));

                    rat1 = sumcomb/sum1;
                    rat2 = sumcomb/sum2;

                    if rat1 >= overlap || rat2 >= overlap
                        cc = corrcoef(traces(t1, :), traces(t2, :));
                        if cc(1, 2) >= ccorr
                            redundant(j) = true;
                        end
                    end
                end
            end
        end
    end
    
    included = ~redundant;
    sortorder = sortorder(included);
end