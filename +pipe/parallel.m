function [pool, sz] = parallel(varargin)
%OPENPARALLEL opens a Matlab pool using the correct conventions for each
%   Matlab version

    p = inputParser;
    addOptional(p, 'size', []);  % Allow for choosing of size workers
    parse(p, varargin{:});
    p = p.Results;    

    % Test if gcp opens a pool
    pool = gcp('nocreate');
    if isempty(pool)
        matlabver = version('-release');
        matlabver = str2num(matlabver(1:end-1));
        hostname = pipe.misc.hostname();
        if matlabver >= 2015
            if strcmpi(hostname, 'megatron')
                sz = 10;
            elseif strcmpi(hostname, 'sweetness')
                if ~isempty(p.size)
                    sz = p.size;
                else
                    sz = 26;
                end
            else
                c = parcluster('local');
                sz = c.NumWorkers - 2;
            end
            pool = parpool(sz);
        else
            if matlabpool('size') == 0
               matlabpool open;
            end
            sz = matlabpool('size');
        end
    else
        sz = pool.NumWorkers - 4;
    end
end

