function last_pc_above_noise = pc_noise(mov, CovEvals)
% last_pc_above_noise = CellsortPlotPCspectrum(fn, CovEvals, PCuse)
%
% Plot the principal component (PC) spectrum and compare with the
% corresponding random-matrix noise floor
%
% Inputs:
%   fn - movie file name. Must be in TIFF format.
%   CovEvals - eigenvalues of the covariance matrix
%   PCuse - [optional] - indices of PCs included in dimensionally reduced
%   data set
%
% Eran Mukamel, Axel Nimmerjahn and Mark Schnitzer, 2009
% Email: eran@post.harvard.edu, mschnitz@stanford.edu
%

[pixw, pixh, nt] = size(mov);
npix = pixw*pixh;

% Random matrix prediction (Sengupta & Mitra)
p1 = npix; % Number of pixels
q1 = nt; % Number of time frames
q = max(p1, q1);
p = min(p1, q1);
sigma = 1;
lmax = sigma*sqrt(p+q + 2*sqrt(p*q));
lmin = sigma*sqrt(p+q - 2*sqrt(p*q));
lambda = [lmin: (lmax-lmin)/100.0123423421: lmax];
rho = (1./(pi*lambda*(sigma^2))).*sqrt((lmax^2-lambda.^2).*(lambda.^2-lmin^2));
rho(isnan(rho)) = 0;
rhocdf = cumsum(rho)/sum(rho);
noiseigs = interp1(rhocdf, lambda, [p:-1:1]'/p, 'linear', 'extrap').^2 ;

% Normalize the PC spectrum
normrank = min(nt-1,length(CovEvals));
pca_norm = CovEvals*noiseigs(normrank) / (CovEvals(normrank)*noiseigs(1));

threshold = 1.5; % used to be 1.5 - RR

%MJLM: Find last PC above 2 * noise floor: used to be 2
last_pc_above_noise = find(pca_norm > max(threshold*noiseigs / noiseigs(1)), 1, 'last');

