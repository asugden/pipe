 function [mixedsig, mixedfilters, CovEvals, covtrace, movm, ...
    movtm] = pca_schnitzer(mov, nPCs, badframes)
    % [mixedsig, mixedfilters, CovEvals, covtrace, movm, movtm] = CellsortPCA(fn, flims, nPCs, dsamp, outputdir, badframes)
    % Edited 170908 by Arthur Sugden and Andrew Lutas to append to changes made
    % by Mathias Minderer and Rohan Ramesh
    %
    % CELLSORT
    % Read TIFF movie data and perform singular-value decomposition (SVD)
    % dimensional reduction.
    %
    % Inputs:
    %   fn - movie file name. Must be in TIFF format.
    %   flims - 2-element vector specifying the endpoints of the range of
    %   frames to be analyzed. If empty, default is to analyze all movie
    %   frames.
    %   nPCs - number of principal components to be returned
    %   dsamp - optional downsampling factor. If scalar, specifies temporal
    %   downsampling factor. If two-element vector, entries specify temporal
    %   and spatial downsampling, respectively.
    %   outputdir - directory in which to store output .mat files
    %   badframes - optional list of indices of movie frames to be excluded
    %   from analysis
    %
    % Outputs:
    %   mixedsig - N x T matrix of N temporal signal mixtures sampled at T
    %   points.
    %   mixedfilters - N x X x Y array of N spatial signal mixtures sampled at
    %   X x Y spatial points.
    %   CovEvals - largest eigenvalues of the covariance matrix
    %   covtrace - trace of covariance matrix, corresponding to the sum of all
    %   eigenvalues (not just the largest few)
    %   movm - average of all movie time frames at each pixel
    %   movtm - average of all movie pixels at each time frame, after
    %   normalizing each pixel deltaF/F
    %
    % Eran Mukamel, Axel Nimmerjahn and Mark Schnitzer, 2009
    % Email: eran@post.harvard.edu, mschnitz@stanford.edu
    %

    %-----------------------
    % Check inputs
    [pixw, pixh, nt_full] = size(mov);
    flims = [1, nt_full];

    useframes = setdiff((flims(1):flims(2)), badframes);
    nt = length(useframes);

    mov = mov(:,:,useframes); %Matt McGill and Andrew updated 10/23/2017
    
    if nargin < 2 || isempty(nPCs), nPCs = min(150, nt); end
    if nargin < 3, badframes = []; end
    npix = pixw*pixh;

    % Create covariance matrix
    fprintf('   %d pixels x %d time frames;', npix, nt)
    if nt < npix
        fprintf(' using temporal covariance matrix.\n')
        [covmat, mov, movm, movtm] = pipe.extract.t_covariance(mov, pixw, pixh, nt);
    else
        fprintf(' using spatial covariance matrix.\n')
        [covmat, mov, movm, movtm] = pipe.extract.x_covariance(mov, pixw, pixh, nt);
    end

    covtrace = trace(covmat)/npix;
    movm = reshape(movm, pixw, pixh);

    if nt < npix
        % Perform SVD on temporal covariance
        [mixedsig, CovEvals, percentvar] = cellsort_svd(covmat, nPCs, nt, npix);

        % Load the other set of principal components
        [mixedfilters] = reload_moviedata(pixw*pixh, mov, mixedsig, CovEvals);
    else
        % Perform SVD on spatial components
        [mixedfilters, CovEvals, percentvar] = cellsort_svd(covmat, nPCs, nt, npix);

        % Load the other set of principal components
        [mixedsig] = reload_moviedata(nt, mov', mixedfilters, CovEvals);
    end
    
    mixedfilters = reshape(mixedfilters, pixw, pixh, nPCs);

    function [mixedsig, CovEvals, percentvar] = cellsort_svd(covmat, nPCs, nt, npix)
        %-----------------------
        % Perform SVD

        covtrace = trace(covmat) / npix;

        opts.disp = 0;
        opts.issym = 'true';
        if nPCs<size(covmat,1)
            [mixedsig, CovEvals] = eigs(covmat, nPCs, 'LM', opts);  % pca_mixedsig are the temporal signals, mixedsig
        else
            [mixedsig, CovEvals] = eig(covmat);
            CovEvals = diag( sort(diag(CovEvals), 'descend'));
            nPCs = size(CovEvals,1);
        end
        CovEvals = diag(CovEvals);
        if nnz(CovEvals<=0)
            nPCs = nPCs - nnz(CovEvals<=0);
            fprintf(['Throwing out ',num2str(nnz(CovEvals<0)),' negative eigenvalues; new # of PCs = ',num2str(nPCs),'. \n']);
            mixedsig = mixedsig(:,CovEvals>0);
            CovEvals = CovEvals(CovEvals>0);
        end

        mixedsig = mixedsig' * nt;
        CovEvals = CovEvals / npix;

        percentvar = 100*sum(CovEvals)/covtrace;
        fprintf([' First ',num2str(nPCs),' PCs contain ',num2str(percentvar,3),'%% of the variance.\n'])
    end

    function [mixedfilters] = reload_moviedata(npix, mov, mixedsig, CovEvals)
        %-----------------------
        % Re-load movie data
        nPCs = size(mixedsig,1);

        Sinv = inv(diag(CovEvals.^(1/2)));

        movtm = mean(mov,1); % Average over space
        movuse = mov - ones(npix,1) * movtm;
        mixedfilters = reshape(movuse * mixedsig' * Sinv, npix, nPCs);
    end
end