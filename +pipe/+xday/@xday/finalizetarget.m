function finalizetarget(obj, bad_days_to_keep, matched_days)
% Splice together warpfields to fix lapses on bad days.

% INPUTS 
% ------
% bad_days_to_keep, array
%   day numbers of the poorly aligned days
% matched_days, array
%   indices of two-stage tiff for poorly aligned days

if nargin < 3 || isempty(matched_days) || ...
   nargin < 2 || isempty(bad_days_to_keep)
   disp('')
   return
end

% load AllWarpFields
AWF = load(obj.warpdir);
AWF = AWF.AllWarpFields;
warpfields = AWF{obj.warptarget};

% load in the non registered FOV
unregmov = pipe.io.read_tiff([obj.savedir filesep ... 
    'FOV_NONregistered_across_days.tif']);

% add in your corrected warpfields
for i = 1:length(bad_days_to_keep)
    bad_day = bad_days_to_keep(i);
    bad_ind = find(ismember(obj.bad_days, bad_day));
    two_stage_AWF = obj.badwarpfields{bad_ind};
    warpfields{bad_day} = two_stage_AWF{matched_days(i)}{bad_day};
end
% obj.badwarpfields = '- conflicts solved -';

% create finalized date/run vectors and warpfields,
% removing indices that were in obj.bad_days, but not 
% bad_days_to_keep input
drop_inds = find(~ismember(obj.bad_days, bad_days_to_keep));
count = 1;
final_warpfields = {};
final_dates = [];
final_runs = {};
for i = 1:length(obj.initial_dates)
    if ismember(i, drop_inds)
        continue
    end
    final_warpfields{count} = warpfields{i};
    final_dates(count) = obj.initial_dates(i);
    final_runs{count} = obj.initial_runs{i};
    count = count + 1;
end
final_unregmov = unregmov(:,:, ~ismember(1:length(obj.initial_dates), ...
    drop_inds));

% populate properties
obj.warpfields = final_warpfields;
obj.final_dates = final_dates;
obj.final_runs = final_runs;

% save finalized tiff stack of your registered FOVs
regmov = zeros(size(final_unregmov));
for i = 1:length(obj.final_dates)
    img = imwarp(final_unregmov(:,:,i), obj.warpfields{i});
    regmov(:, :, i) = img;
end

% write tiff stacks of final results pre and post registration
pipe.io.write_tiff(regmov,[obj.savedir filesep ...
    'FOV_registered_to_day_' num2str(obj.warptarget) '.tif']);
pipe.io.write_tiff(unregmov,[obj.savedir filesep ...
    'FOV_NONregistered_to_day_' num2str(obj.warptarget) '_final.tif']);

% save xday object
save([obj.savedir filesep 'xday_obj'],'obj','-v7.3')

end