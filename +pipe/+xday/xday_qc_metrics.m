function xday_qc_metrics(obj, cell_score_threshold)
%xday_qc_metrics - plot and save PNGs of quick analysis of finished crossday alignment 

%% General graphics, this will apply to any figure you open
% (groot is the default figure object).
set(groot, ...
'DefaultFigureRenderer', 'painters', ...
'DefaultFigureColor', 'w', ...
'DefaultAxesLineWidth', 1.5, ...
'DefaultAxesXColor', 'k', ...
'DefaultAxesYColor', 'k', ...
'DefaultAxesFontUnits', 'points', ...
'DefaultAxesFontSize', 13, ...
'DefaultAxesFontName', 'Helvetica', ...
'DefaultAxesBox', 'off', ...
'DefaultAxesTickDir', 'in', ...
'DefaultAxesTickDirMode', 'manual', ...
'DefaultLineLineWidth', 1.5, ...
'DefaultHistogramLineWidth', 1.5, ...
'DefaultTextFontUnits', 'Points', ...
'DefaultTextFontSize', 13, ...
'DefaultTextFontName', 'Helvetica');

% set cell_score threshold if unset
if nargin < 2 || isempty(cell_score_threshold)
    cell_score_threshold = 0;
end

%% Set path for saving 
if isprop(obj, 'bridgealignment')
    stag = 'bridge_';
elseif isprop(obj, 'xdayalignment')
    stag = 'xday_';
end
xday_folder = [obj.savedir filesep 'xday_qc_metrics_' stag num2str(cell_score_threshold)];
if ~exist(xday_folder)
    mkdir(xday_folder)
end

%% set your index variables
xday_scores = obj.xdayalignment.cell_scores;
xday_inds = obj.xdayalignment.cell_to_index_map;
xday_inds = xday_inds(xday_scores >= cell_score_threshold,:);

% define major variables
if isprop(obj, 'bridgealignment')
    xday_scores = obj.bridgealignment.cell_scores;
    xday_inds = obj.bridgealignment.cell_to_index_map;
elseif isprop(obj, 'xdayalignment')
    xday_scores = obj.xdayalignment.cell_scores;
    xday_inds = obj.xdayalignment.cell_to_index_map;
end
xday_inds = xday_inds(xday_scores >= cell_score_threshold,:);

% make sure that empties are zeros and not NaNs 
xday_inds(isnan(xday_inds)) = 0;

%------------------------------------------------------------------------------
%% how many days are each cell present? 
sum_inds_xday = sort(sum(xday_inds > 0, 2), 'descend');
hist_pcaica = histc(sum_inds_xday,1:length(obj.final_dates));
cum_pcaica = cumsum(hist_pcaica);
total_pcaica = sum(hist_pcaica);

% set x-axes 
x_ax_fwd = 1:length(obj.final_dates);
x_ax_rev = length(obj.final_dates):-1:1;

% plot the cumulative cell number for max days, max-1 days, ... 
figure;
plot(x_ax_rev, cumsum(sort(hist_pcaica, 'ascend')), 'color', [0.1 0.8 0], 'LineWidth', 2);
set(gca, 'XDir','reverse')
title('Inverted cumulative number of cells identified across a given number of days')
xlabel('Days')
ylabel('Number of cells')
xlim([1 length(obj.final_dates)])
ylim([0 inf])
set(gca, 'box', 'off');
% save
print([xday_folder filesep 'inv_cumulative_cells_plot'], '-dpng');


% plot the cumulative fraction of cells aligned for a given number of days
figure;
plot(x_ax_fwd, cum_pcaica, 'color', [0.1 0.8 0], 'LineWidth', 2); 
title('Cumulative number of cells identified across a given number of days')
xlabel('Days')
ylabel('Number of cells')
xlim([1 length(obj.final_dates)])
ylim([0 inf])
set(gca, 'box', 'off');
% save
print([xday_folder filesep 'cumulative_cells_plot'], '-dpng');


% plot the cumulative fraction of cells aligned for a given number of days
figure;
plot(x_ax_fwd, cum_pcaica./total_pcaica, 'color', [0.1 0.8 0], 'LineWidth', 2);
title('Cumulative fraction of cells identified across a given number of days')
xlabel('Days')
ylabel('Fraction of total cells')
xlim([1 length(obj.final_dates)])
ylim([0 1])
set(gca, 'box', 'off');
% save 
print([xday_folder filesep 'cumulative_fraction_plot'], '-dpng');


% plot a histogram of the number of cells found across a given # of days ...
figure;
histogram(sum_inds_xday, 'FaceColor', [0.1 0.8 0], ...
                                'LineWidth', 1.5, ...
                                'EdgeColor', [0.1 0.8 0] ...
                                ); %green CR pcaica
title('Number of cells registered for # of days')
xlabel('Days')
ylabel('Number of cells') 
xlim([0.5 (length(obj.final_dates)+0.5)])
set(gca, 'box', 'off');
% save 
print([xday_folder filesep 'total_days_per_cell_hist'], '-dpng');

%------------------------------------------------------------------------------
%% how stable are cell counts over time? 
cellsperday_pcaica_inds_xday = sum(xday_inds > 0, 1);
m_pcaica = mean(cellsperday_pcaica_inds_xday);
std_pcaica = std(cellsperday_pcaica_inds_xday);

figure;
plot(cellsperday_pcaica_inds_xday, 'color', [0.1 0.8 0], 'LineWidth', 2); hold on %green 
title('Total cells per day')
xlabel('Days')
ylabel('Number of cells')
xlim([1 length(obj.final_dates)])
set(gca, 'box', 'off');
% save 
print([xday_folder filesep 'cells_per_day'], '-dpng');

%------------------------------------------------------------------------------
%% Range or max "span" of each cell
ranger1 = zeros(size(xday_inds, 1),1);
for i = 1:size(xday_inds, 1);
    if sum(xday_inds(i,:) > 0) > 1
        rangefinder = range(find(xday_inds(i,:)));
        ranger1(i) = rangefinder; 
    end
end
ranger1 = ranger1(ranger1 ~= 0); 

% Plot a histogram of ranges
figure; 
histogram(ranger1, 'FaceColor', [0.1 0.8 0], ...
                                'LineWidth', 1.5, ...
                                'EdgeColor', [0.1 0.8 0] ...
                                ); hold on %green CR pcaica
title('Max span of each cell')
xlabel('Days')
ylabel('Number of cells') 
xlim([0.5 (length(obj.final_dates)-0.5)])
set(gca, 'box', 'off');
% save
print([xday_folder filesep 'max_span'], '-dpng');

%------------------------------------------------------------------------------
%% Heatmap: for cells identified on a given day, how many of those are found on another day?
crossx = zeros(length(obj.final_dates));
for i = 1:length(obj.final_dates)
    binary_inds = xday_inds ~= 0;
    [~, resort_ind] = sort(xday_inds(:,i) ~= 0,'descend');
    sorted_inds = binary_inds(resort_ind,:);
    todays_cell_num = sum(sorted_inds(:,i),1);
    crossx(i,:) = sum(sorted_inds(1:todays_cell_num, :),1); 
end

figure;
imagesc(crossx)
title('\fontsize{8}For cells identified on a given day, how many of those are found on another day');
xlabel('Day #');
ylabel('Day #');
try
    colormap('inferno')
end
c = colorbar;
c.Label.String = 'Cells';
c.Label.FontSize = 14;
% save
print([xday_folder filesep 'cell_transitions_heatmap'], '-dpng');

%------------------------------------------------------------------------------
%% Binary map: days that each cell has a mask
figure;
imagesc(xday_inds ~= 0)
title('Registered cell masks');
xlabel('Day #');
ylabel('Cell #');
try
    colormap('inferno')
end
% save
print([xday_folder filesep 'cell_transitions_binarymap'], '-dpng');


end %main function end 