function deconvolved = deconvolve(dffs)
% Wrapper function for deconvolution using the FOOPSI algorithm
% (https://github.com/epnev/constrained-foopsi).
% Inputs: 
%       dffSubt     nTraces-by-nTimepoints matrix of neuropil-subtracted DFF
%                   fluorescence data
%
% Outputs:
%       out         Structure containing the output of the
%                   constrained_foopsi function (see below), as well as a
%                   version of the output that is scaled to units of spikes
%                   per timepoint (deconvInSpikes; see explanation below).

    opt.p = 4; % Order of autoregressive model.
    opt.method = 'cvx'; % spgl1 is an alternative, but takes a lot of time
    opt.bas_nonneg = 1; % flag for setting the baseline lower bound. if 1, then b >= 0 else b >= min(y)
    opt.noise_range = [1/4,1/2]; % frequency range over which the noise power is estimated. Default [Fs/4,Fs/2]
    opt.noise_method = 'logmexp';
    opt.lags = 20;
    opt.ressparse = 0;
    opt.fudge_factor = 0.98;

    % Unitary DF size: The scaling of the deconvolution output is somewhat
    % arbitrary. Here, we scale it such that the result is given in units of
    % spikes per timepoint. To do this, the algorithm needs to know how large a
    % single spike is in DFF. This depends on the calcium indicator. Reasonable
    % values can be obtained from the GCaMP6 paper. (The normalization code was
    % written by Selmaan from the Harvey Lab.)
    unitaryDF = 0.15; 

    % Documentation for the FOOPSI inputs and outputs:
    %   Variables:
    %   y:      raw fluorescence data (vector of length(T))
    %   c:      denoised calcium concentration (Tx1 vector)
    %   b:      baseline concentration (scalar)
    %  c1:      initial concentration (scalar)
    %   g:      discrete time constant(s) (scalar or 2x1 vector)
    %  sn:      noise standard deviation (scalar)
    %  sp:      spike vector (Tx1 vector)

    %   USAGE:
    %   [c,b,c1,g,sn,sp] = constrained_foopsi(y,b,c1,g,sn,OPTIONS)
    %   The parameters b,cin,g,sn can be given or else are estimated from the data

    %   OPTIONS: (stuct for specifying options)
    %         p: order for AR model, used when g is not given (default 2)
    %    method: methods for performing spike inference
    %   available methods: 'dual' uses dual ascent
    %                       'cvx' uses the cvx package available from cvxr.com (default)
    %                      'lars' uses the least regression algorithm 
    %                     'spgl1' uses the spgl1 package available from
    %                     math.ucdavis.edu/~mpf/spgl1/  (usually fastest)
    %   bas_nonneg:   flag for setting the baseline lower bound. if 1, then b >= 0 else b >= min(y)
    %   noise_range:  frequency range over which the noise power is estimated. Default [Fs/4,Fs/2]
    %   noise_method: method to average the PSD in order to obtain a robust noise level estimate
    %   lags:         number of extra autocovariance lags to be considered when estimating the time constants
    %   resparse:     number of times that the solution is resparsened (default 0). Currently available only with methods 'cvx', 'spgl'
    %   fudge_factor: scaling constant to reduce bias in the time constant estimation (default 1 - no scaling)

    %% Account for nanrows
    
    dffs = double(dffs);
    ncells = size(dffs, 1);
    nframes = size(dffs, 2);
    deconvolved = NaN(ncells, nframes);
    
    nanrows = zeros(1, ncells);
    for c = 1:size(dffs, 1)
        if sum(isnan(dffs(c, :))) > nframes/2
            nanrows(c) = 1;
        end
    end

    if sum(nanrows) == 0
        nndffs = dffs;
    else
        nndffs = dffs(nanrows == 0, :);
    end
    
    %% Submit
    
    ncells = size(nndffs, 1);

    c = zeros(size(nndffs));
    b = zeros(ncells, 1);
    c1 = zeros(ncells, 1);
    g = zeros(ncells, opt.p);
    sn = zeros(ncells, 1);
    deconvInSpikes = zeros(size(nndffs));
    
    parfor i = 1:size(nndffs, 1)
        y = nndffs(i, :);
        [c(i, :), b(i), c1(i), g(i, :), sn(i), sp] = ...
            constrained_foopsi(y, [], [], [], [], opt);
        maxPulse = max(impulseAR(g(i, :)));
        deconvInSpikes(i, :) = sp*maxPulse/unitaryDF;
    end
    
    %% Fix for nanrows
    
    deconvolved(nanrows == 0, :) = deconvInSpikes;
end

function impulseResponse = impulseAR(p)

    impulseResponse = zeros(1e3,1);
    impulseResponse(50) = 1;
    p = p(:)';

    for ind = 51:1e3
        impulseResponse(ind) = p*impulseResponse(ind-1:-1:ind-length(p));
    end
end
