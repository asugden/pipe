function [best_model, best_inliers, xy, n_inliers] = ransac_ellipse(data, EllipseCenter, ...
    residual_threshold, min_samples, max_trials, calcTheta, ellipseFit)
% converted to MATLAB from https://github.com/scikit-image/scikit-image/blob/master/skimage/measure/fit.py#L380

% Fit a model to data with the RANSAC (random sample consensus) algorithm.
%     RANSAC is an iterative algorithm for the robust estimation of parameters
%     from a subset of inliers from the complete data set. Each iteration
%     performs the following tasks:
%     1. Select `min_samples` random samples from the original data and check
%        whether the set of data is valid (see `is_data_valid`).
%     2. Estimate a model to the random subset
%        (`model_cls.estimate(*data[random_subset]`) and check whether the
%        estimated model is valid (see `is_model_valid`).
%     3. Classify all data as inliers or outliers by calculating the residuals
%        to the estimated model (`model_cls.residuals(*data)`) - all data samples
%        with residuals smaller than the `residual_threshold` are considered as
%        inliers.
%     4. Save estimated model as best model if number of inlier samples is
%        maximal. In case the current estimated model has the same number of
%        inliers, it is only considered as the best model if it has less sum of
%        residuals.
%     These steps are performed either a maximum number of times or until one of
%     the special stop criteria are met. The final model is estimated using all
%     inlier samples of the previously determined best model.
if nargin < 7
    ellipseFit = 'LS';
end
if nargin < 6 || isempty(calcTheta)
    calcTheta = 1;
end
if nargin < 5 || isempty(max_trials)
    max_trials = 100;
end
if nargin < 4 || isempty(min_samples)
    min_samples = 5;
end
if nargin < 3 || isempty(residual_threshold)
    residual_threshold = 3;
end

switch ellipseFit
    case 'LS'
        ellipseFunc = @pipe.pupil.ellipse_lsq;
    case 'conic'
        error('Conic not implemented.');
        % ellipseFunc = @fitEllipseConic;
    otherwise
        error('Please select LS or conic for fit');
end

n_inliers = 0;

x = data(1, :);
y = data(2, :);

best_model = [];
best_inlier_num = 0;
best_inlier_residuals_sum = Inf;
best_inliers = [];
stop_sample_num = Inf;
stop_residuals_sum = 0;
stop_probability = 0.99;
t0 = [];

assert(min_samples > 0, 'Min samples must be greater than zero');
assert(max_trials > 0, 'Max_trials must be greater than zero');
assert(stop_probability > 0 && stop_probability < 1, 'stop_probability must be in range [0,1]')

num_samples = length(x);

%fit ellipse to all good samples to have a good t0
% if ~calcTheta
%     distCutoff = 30;
%     closeSamp = abs(x-EllipseCenter(1)) < distCutoff & abs(y-EllipseCenter(2)) < distCutoff;
%     [simple_model, xy_simple] = fitEllipseLS(x(closeSamp), y(closeSamp));
%     [residuals, t0] = EllipseRes(x, y, simple_model, t0);
% end

for num_trial = 1:max_trials
    % select random subset, repeat until different x and y values for each
    while 1
        subset = randperm(num_samples, min_samples);
        epx = x(subset);
        epy = y(subset);
        %         if length(unique(epy))==length(epy) && length(unique(epx))==length(epx)
        if ~any(diff(sort(epx))==0) || ~any(diff(sort(epy))==0)
            % fit ellipse model
            [sample_model, xy] = feval(ellipseFunc, epx, epy);
            if isempty(sample_model) && isempty(xy), return; end
            if isreal(sample_model) && ~isempty(sample_model)
                break;
            end
        end
    end
    
    % residuals over all data
    [sample_model_residuals, t0] = pipe.pupil.ellipse_residuals(x, y, sample_model, t0, calcTheta);
    
    sample_model_residuals = abs(sample_model_residuals);
    sample_model_inliers = sample_model_residuals < residual_threshold;
    sample_model_residuals_sum = sum(sample_model_residuals.^2);
    
    sample_inlier_num = sum(sample_model_inliers);
    if (sample_inlier_num > best_inlier_num || (sample_inlier_num == best_inlier_num && sample_model_residuals_sum < best_inlier_residuals_sum))
        best_model = sample_model;
        best_inlier_num = sample_inlier_num;
        best_inlier_residuals_sum = sample_model_residuals_sum;
        best_inliers = sample_model_inliers;
        
        if (best_inlier_num >= stop_sample_num || best_inlier_residuals_sum <= stop_residuals_sum || ...
                num_trial >= dynamic_max_trials(best_inlier_num, num_samples,...
                min_samples, stop_probability))
            break;
        end
    end
end
% fit best model with inliers
if ~isempty(best_inliers)
    if sum(best_inliers) > min_samples
        [best_model, xy] = feval(ellipseFunc, x(best_inliers), y(best_inliers));
        n_inliers = sum(best_inliers);
    else
        % warning('No inliers found');
        distCutoff = 30;
        closeSamp = abs(x-EllipseCenter(1)) < distCutoff & abs(y-EllipseCenter(2)) < distCutoff;
        if sum(closeSamp) >= 5
            [best_model, xy] = feval(ellipseFunc,x(closeSamp), y(closeSamp));
        else
            [best_model, xy] = feval(ellipseFunc, x, y);
        end
        n_inliers = 1;
    end
end

end

function dMax_trial = dynamic_max_trials(n_inliers, n_samples, min_samples, probability)
dMax_trial = [];
if n_inliers == 0
    dMax_trial = Inf;
end

nom = 1 - probability;
if nom == 0
    dMax_trial = Inf;
end

inlier_ratio = n_inliers / n_samples;
denom = 1 - inlier_ratio.^min_samples;

if denom == 0
    dMax_trial = 1;
elseif denom == 1
    dMax_trial = Inf;
end

nom = log(nom);
denom = log(denom);
if denom == 0
    dMax_trial = 0;
end

if isempty(dMax_trial)
    dMax_trial = ceil(nom / denom);
end
end




