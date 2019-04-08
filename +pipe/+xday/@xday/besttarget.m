function besttarget(obj, best_day, bad_days)
% Function to aid in alignment of FOV registered using
% imregdemons. Creates best alignment obj.warpfields. If
% bad_days is empty, this is populated by a finalized best set
% of warpfields. If bad_days exist, creates tiffs to help user
% solve poorly registered days and populates obj.warpfields 
% with temporary two_stage warpfields. 

% populate properties of xday class
obj.warptarget = best_day;

% load AllWarpFields
AWF = load(obj.warpdir);
AWF = AWF.AllWarpFields;

% load in the non registered FOV
UnregMov = pipe.io.read_tiff([obj.savedir filesep ... 
    'FOV_NONregistered_across_days.tif']);

% If there are NO bad days, finalize target day and
% build warpfields property. If there ARE bad days, 
% create tiff stacks of bad days warped through other days.
if nargin < 3 || isempty(bad_days)

    % register to best_day
    RegMov = zeros(size(UnregMov));
    for i = 1:length(obj.initial_dates)
        img = imwarp(UnregMov(:,:,i), AWF{best_day}{i});
        RegMov(:, :, i) = img;
    end

    % write tiff stack registered to best_day
    pipe.io.write_tiff(RegMov,[obj.savedir filesep ...
        'FOV_registered_to_day_' num2str(best_day) '.tif'])

    % add finalized warpfields to xday object
    obj.warpfields = AWF{best_day};
    obj.final_dates = obj.initial_dates;
    obj.final_runs = obj.initial_runs;
    obj.badwarpfields = '- no conflicts -';

else
    % create all possible warpfields for each two-stage registration
    badwarps = cell(length(bad_days));
    for j = 1:length(bad_days)
        k = bad_days(j);
        % preallocate
        for i = 1:length(obj.initial_dates)
            for j = 1:length(obj.initial_dates)
                two_stage_AWF{i}{j} = [];
            end
        end
        % RegMov = zeros(size(UnregMov));
        RegMov = [];
        for i = 1:length(obj.initial_dates)
            two_stage_AWF{i}{k} = AWF{best_day}{i} + AWF{i}{k};
            img = imwarp(UnregMov(:,:,i), two_stage_AWF{i}{k});
            % RegMov(:, :, i) = img;
            img2 = cat(3, UnregMov(:, :, best_day), img);
            RegMov = cat(3, RegMov, img2);
        end

        % save two_stage warps for each bad day 
        warpdir = [obj.savedir filesep 'bad_day_' num2str(k) ...
            '_warpfields.mat'];
        save(warpdir, 'two_stage_AWF', '-v7.3')

        % write tiff stack registered to best_day
        pipe.io.write_tiff(RegMov, [obj.savedir filesep ...
            'bad_day_' num2str(k) '_to_day_' num2str(best_day) ...
            '_two_stage.tif'])

        % hold onto your two stage warps in xday until you solve them
        badwarps{j} = two_stage_AWF;
    end

    % add temporary bad warpfields to xday object
    obj.badwarpfields = badwarps;
    obj.bad_days = bad_days;

    % output for user
    disp(['Two-stage registration done: Go to ' obj.savedir])
    disp(['    1. Please look through your bad_day_N_to_day_' ...
          num2str(best_day) '_two_stage.tifs'])
    disp('       to determine best two-stage registration path.')
    disp('    2. Run obj.finalizetarget...')
end

% save xday object
save([obj.savedir filesep 'xday_obj'],'obj','-v7.3')

end