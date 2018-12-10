function out = trial_times(mouse, date, run, server, force, allowrunthrough, interpolate2p, ttlv, miniti)
    % Return the onset times and codes of monkeylogic stimuli for a
    % particular mouse, date, and run.
    
    % If allowrunthrough is set to true, if scanbox cuts out but the ephys
    % still records frames, it will assume that the last frames recorded by
    % ephys don't matter.
    
    % If interpolate2p is set to true, assume that some 2p pulses are
    % missing, but trust the initial pulse

    % Set the forcing to be false
    if nargin < 4, server = []; end
    if nargin < 5, force = false; end
    if nargin < 6, allowrunthrough = false; end
    if nargin < 7, interpolate2p = false; end
    
    % Check if already created
    spath = pipe.path(mouse, date, run, 'onsets', server, 'estimate', true);
    if ~force && exist(spath)
        out = load(spath, '-mat');
        return
    end

    % Set the TTL voltage threshold for measuring stimulus onsets
    if nargin < 8
        ttlv = 1.0;
        miniti = 5;
    end

    % Load nidaq data
    nidaq = pipe.io.read_sbxephys(mouse, date, run, server, [], interpolate2p);
    nframes = nidaq.nframes;

    % Get the timing of monitor frames
    onset2p = monitorFrameOnsets(nidaq.frames2p, nidaq.timeStamps, nframes, allowrunthrough);
    if isempty(onset2p)
        % This should only happen if there was a fatal error in ephys
        error(sprintf('Forced to quit in measurement of event onsets. Frames did not match for %s on %s run %i\n', mouse, date, run));
    end

    lickingt = ttledges(nidaq.licking, nidaq.timeStamps, 0.050);
    licking = localTimesToOnsets(onset2p, lickingt);
    
    
    % Check if this is a spontaneous run or not
    if isempty(pipe.path(mouse, date, run, 'bhv', server))
        % And save
        save(spath, 'licking');
        out = struct('licking', licking);
        return
    end

    % Load in the monkeylogic file
    ml = pipe.load(mouse, date, run, 'bhv', server);
    
    % Clean up duplicated stimuli (only for shown stimuli)
    conds = zeros(1, length(ml.TimingFileByCond));
    for i = 1:length(ml.TimingFileByCond)
        conds(i) = sum(ml.ConditionNumber == i);
    end
        
    for i = 2:length(ml.TimingFileByCond)
        if conds(i) > 0
            tfile = strrep(lower(ml.TimingFileByCond{i}), '_runtime', '');
            
            for j = 1:i-1
                if conds(j) > 0 && strcmp(tfile, strrep(lower(ml.TimingFileByCond{j}), '_runtime', ''))
                    % Found a matching condition file, now checking for
                    % matching movies
                    matched = true;
                    for k = 1:size(ml.TaskObject, 2)
                        if ml.TaskObject{i, k} ~= ml.TaskObject{j, k}
                            matched = false;
                        end
                    end
                    
                    if matched
                        ml.ConditionNumber(ml.ConditionNumber == i) = j;
                        conds(i) = 0;
                    end
                end
            end
        end
    end
    
    % Get the timing of visual stimuli
    [onsetst, offsetst] = ttledges(nidaq.visstim, nidaq.timeStamps, miniti, ttlv);
    
    % Convert to onsets
    onsets = localTimesToOnsets(onset2p, onsetst);
    offsets = localTimesToOnsets(onset2p, offsetst);

    % Check that the number found is correct
    if length(onsetst) ~= length(ml.ConditionNumber)
        if length(onset2p) - onsets(end) < 1.5*median(diff(onsets))
            disp(sprintf('Warning: the number of stimuli %i presented does not match the number recorded, %i. \nHowever, it appears that the stimulus just ran through the end so we will allow it through.', length(ml.ConditionNumber), length(onsetst)));
        else
            warndlg(sprintf(...
                'There is an error in the number of monkeylogic stimuli presented, %i, and the number detected by the nidaq card, %i.',...
                length(ml.ConditionNumber), length(onsetst)));
            return
        end
    end

    % Get the time onsets of licking, ensure, and quinine
    ensuret = ttledges(nidaq.ensure, nidaq.timeStamps, 0.050);
    quininet = ttledges(nidaq.quinine, nidaq.timeStamps, 0.050);

    % Convert to trial onsets
    ensure = trializeOnsets(onsets, localTimesToOnsets(onset2p, ensuret));
    quinine = trializeOnsets(onsets, localTimesToOnsets(onset2p, quininet));

    % Get key data from ML
    condition = uint8(ml.ConditionNumber);
    trialerror = uint8(ml.TrialError);

    % Get first lick
    % Calculate the first lick
    firstlick = NaN(1, length(onsets));
    for i = 1:length(onsets)
        lick = licking(find(licking > onsets(i), 1));
        if ~isempty(lick) && (i == length(onsets) || lick < onsets(i+1))
            firstlick(i) = lick;
        end
    end
    
    % Check whether it is retinotopy or a stimulus run
    codes = timingFileCodes(ml);
    orientation = orientationCodes(ml, codes);
    
    % And save
    save(spath, 'onsets', 'offsets', 'licking', 'ensure', 'quinine', ...
        'condition', 'trialerror', 'codes', 'orientation');

    out = struct('onsets', onsets, 'offsets', offsets, 'licking', licking, ...
        'ensure', ensure, 'quinine', quinine, 'condition', condition, ...
        'trialerror', trialerror, 'codes', codes, ...
        'orientation', orientation);
end


function out = localTimesToOnsets(time2p, timestim)
    % Convert an array of times to an array of frame onsets
    if length(time2p) < 2^16 - 1
        out = zeros(length(timestim), 1, 'uint16');
    else
        out = zeros(length(timestim), 1, 'uint32');
    end
    
    last = 1;
    toomany = 0;
    for i=1:length(timestim)
        last = (last - 1) + find(time2p(last:end) > timestim(i), 1);
        if ~isempty(last)
            out(i) = last;
        else
            toomany = toomany + 1;
            out(i) = -1;
        end
    end
    
    if toomany > 0
        out = out(1:end - toomany);
    end
end


function out = trializeOnsets(trial, stim)
    % Convert an array of quinine or ensure onsets to be within each trial
    if max(stim) < 2^16 - 1
        out = zeros(length(trial), 1, 'uint16');
    else
        out = zeros(length(trial), 1, 'uint32');
    end

    last = 1;
    for i=1:length(stim)
        last = (last - 1) + find(trial(last:end) > stim(i), 1);
        if last > 1
            out(last-1) = stim(i);
        end
    end
end


function [onsets, offsets] = ttledges(ttl, timestamps, mininterval, ttlv)
%sbxTTLOnsets Convert a TTL signal recorded by a nidaq into a series of
%   onsets with a minimum interval of mininterval and a threshold voltage
%   of ttlv

    % Assume an interval of at least 50 ms and TTL threshold voltage of 2.0
    if nargin < 3
        mininterval = 0.050;
    end
    if nargin < 4
        ttlv = 2.0;
    end
    
    % Threshold the stimuli
    ind = find(diff(ttl > ttlv) == 1);
    samplefreq = 1./diff(timestamps(1:2));
    ind(find((diff(ind)./samplefreq) < .01)) = [];
    onsets = timestamps(ind);
    
    % Eliminate onsets faster than mininterval
    diff_ind = diff([-1*mininterval ;onsets]);
    ind_error = find(diff_ind < mininterval);
    onsets(ind_error) = [];

    % Remove onsets if pulse begins high
    ind2 = find(diff(ttl > ttlv) == -1);
    ind2(find((diff(ind2)./samplefreq) < .01)) = [];
    if ~isempty(ind) && ~isempty(ind2) && ind2(1) < ind(1)
        ind2(1) = [];
    end
    
    % Calculate offests if need be
    offsets = timestamps(ind2);
    diff_ind2 = diff([-1*mininterval ;offsets]);
    ind_error2 = find(diff_ind2 < mininterval);
    offsets(ind_error2) = [];

end


function framet = monitorFrameOnsets(nidaq, timestamps, nframes, allowrunthrough)
% getSbxMonitorFrames gets the timing of monitor frames given a nidaq
% channel and nidaq timestamps that have been sorted.

    if nargin < 4, allowrunthrough = false; end

    % Use simple thresholding to get frame onset times from the analog frame
    % signal recorded by the NiDAQ system:
    threshold = range(nidaq)/2;
    if threshold > 3 || threshold < 2
        fprintf('Warning: TTL threshold is out of normal boundaries at %.1f', threshold);
    end

    ind = find(diff(nidaq > threshold) == 1); % Rising edge
    samplefreq = 1./diff(timestamps(1:2));
    ind(find((diff(ind)./samplefreq) < .01)) = [];
    framet = timestamps(ind);
    framet(1) = [];

    % Check if the pulse rate is close to double the number of frames
    % The new rig sends out pulses only on forward mirror motion
    if abs(length(framet)*2 - nframes) <= 2 % (TTL sometimes ends in up state)
        framet = interp1(1:2:length(framet)*2, framet, 0:length(framet)*2 - 1, 'linear', 'extrap');
        warning('Artificially adding pulses for flyback.')
    end

    % Check if pulses match frames
    if allowrunthrough && numel(framet) > nframes
        framet = framet(1:nframes);
    elseif numel(framet) < nframes - 2 || numel(framet) > nframes
        w = warndlg(sprintf('Frame onsets measured by ephys, %i, do not match %i frames in movie', length(framet), nframes));
        fprintf('Frame onsets measured by ephys, %i, do not match %i frames in movie', length(framet), nframes);
        framet = [];
    end
end


function codes = timingFileCodes(ml)
%SBXONSETSCODES Returns a cell array of names that correspond with numbers
%   of trial types, takes a monkey logic file

    nametable = { ...
        'pavlovian_csp_2s.m', 'pavlovian', ...
        'pavlovian_csm_2s.m', 'pavlovian_minus', ...
        'rotate_pavlovian_timing.m', 'pavlovian', ...
        'csp_cond_2s_end.m', 'plus', ...
        'rotate_plus_timing.m', 'plus', ...
        'csm_cond_2s_end.m', 'minus', ...
        'rotate_minus_timing.m', 'minus', ...
        'csn_cond_2s_end.m', 'neutral', ...
        'blank_2s.m', 'blank', ...
        'csp_cond_2s_catch_end.m', 'catch', ...
        'blank_2s_reward.m', 'blank_reward', ...
        'monitoroff.m', 'monitor', ...
        'csp_primetime.m', 'plus', ...
        'csn_primetime.m', 'neutral', ...
        'csm_primetime.m', 'minus', ...
        'csn_cond_2s_end_dis1.m', 'disengaged1', ...
        'csn_cond_2s_end_dis2.m', 'disengaged2', ...
        'ori_cond_2s_end.m', 'orientation', ...
        'pavlovian_csp_3s.m', 'pavlovian', ...
        'csp_cond_3s_end.m', 'plus', ...
        'csm_cond_3s_end.m', 'minus', ...
        'csn_cond_3s_end.m', 'neutral', ...
        'csp_cond_3s_catch_end.m', 'plus', ...
        'csp_cond_3s_end_aud.m', 'plus', ...
        'pavlovian_csp_2s_aud.m', 'pavlovian', ...
    };
    nnames = length(nametable)/2;

    names = {};
    vals = {};
    for i = 1:length(ml.TimingFileByCond)
        if sum(ml.ConditionNumber == i) > 0
            names{end+1} = strrep(lower(ml.TimingFileByCond{i}), '_runtime', '');
            
            % For retinotopy
            if strcmp(names{end}, 'ori_cond_2s_end.m')
                names{end} = lower(ml.Stimuli.MOV(i).Name);
            end

            for j = 1:nnames
                if strcmp(names{end}, nametable{j*2 - 1})
                    names{end} = nametable{j*2};
                end
            end

            dotpos = strfind(names{end}, '.');
            if ~isempty(dotpos)
                names{end} = names{end}(1:dotpos - 1);
            end

            vals{end+1} = i;
            
            % Check for multi-contrast runs
            for j = 1:size(ml.TaskObject, 2)
                if ~isempty(strfind(ml.TaskObject{i, j}, 'Mov'))
                    if ~isempty(strfind(ml.TaskObject{i, j}, 'Contr_0.1'))
                        names{end} = [names{end} '_low'];
                    elseif ~isempty(strfind(ml.TaskObject{i, j}, 'Contr_0.3'))
                        names{end} = [names{end} '_med'];
                    end
                end
            end
        end
    end
    
    codes = cell2struct(vals, names, 2);
end


function [oris, codes] = orientationCodes(ml, codes)
%SBXONSETSCODES Returns a cell array of names that correspond with numbers
%   of trial types, takes a monkey logic file

    nametable = { ...
        'Mov(CSp_primetime,0,0)', 0, ...
        'Mov(CSn_primetime,0,0)', 135, ...
        'Mov(CSm_primetime,0,0)', 270, ...
        'Mov(Ori_0,0,0)', 0, ...
        'Mov(Ori_0,0,45)', 45, ...
        'Mov(Ori_0,0,90)', 90, ...
        'Mov(Ori_0,0,135)', 135, ...
        'Mov(Ori_0,0,180)', 180, ...
        'Mov(Ori_0,0,225)', 225, ...
        'Mov(Ori_0,0,270)', 270, ...
        'Mov(Ori_0,0,315)', 315, ...
        'Mov(dis_67_pt_5deg_FF,0,0)', 67.5, ...
        'Mov(Mov_270_Contr_1,0,0)', 270, ...
        'Mov(Mov_135_Contr_1,0,0)', 135, ...
        'Mov(Mov_0_Contr_1,0,0)', 0, ...
        'Mov(Mov_270_Contr_0.1,0,0)', 270, ...
        'Mov(Mov_135_Contr_0.1,0,0)', 135, ...
        'Mov(Mov_0_Contr_0.1,0,0)', 0, ...
        'Mov(Mov_270_Contr_0.02,0,0)', 270, ...
        'Mov(Mov_135_Contr_0.02,0,0)', 135, ...
        'Mov(Mov_0_Contr_0.02,0,0)', 0, ...
        'Mov(Mov_270,0,0)', 270, ...
        'Mov(Mov_135,0,0)', 135, ...
        'Mov(Mov_0,0,0)', 0, ...
        'Mov(0deg_FF,0,0)', 0, ...
        'Mov(0deg_topL,0,0)', 0, ...
        'Mov(135deg_FF,0,0)', 135, ...
        'Mov(135deg_topL,0,0)', 135, ...
        'Mov(180deg_FF,0,0)', 180, ...
        'Mov(180deg_topL,0,0)', 180, ...
        'Mov(225deg_FF,0,0)', 225, ...
        'Mov(225deg_topL,0,0)', 225, ...
        'Mov(270deg_FF,0,0)', 270, ...
        'Mov(270deg_topL,0,0)', 270, ...
        'Mov(315deg_FF,0,0)', 315, ...
        'Mov(315deg_topL,0,0)', 315, ...
        'Mov(45deg_FF,0,0)', 45, ...
        'Mov(45deg_topL,0,0)', 45, ...
        'Mov(90deg_FF,0,0)', 90, ...
        'Mov(90deg_topL,0,0)', 90, ...
        'Mov(Mov_0_Contr_0.3,0,0)', 0, ...
        'Mov(Mov_135_Contr_0.3,0,0)', 135, ...
        'Mov(Mov_270_Contr_0.3,0,0)', 270, ...
        'Mov(Ori_135,0,0)', 135, ...
        'Mov(Ori_180,0,0)', 180, ...
        'Mov(Ori_225,0,0)', 225, ...
        'Mov(Ori_270,0,0)', 270, ...
        'Mov(Ori_315,0,0)', 315, ...
        'Mov(Ori_45,0,0)', 45, ...
        'Mov(Ori_90,0,0)', 90, ...
    };
    nnames = length(nametable)/2;
    npossibles = size(ml.TaskObject, 2);

    orinumbers = [];
    for i = 1:length(ml.TaskObject)
        if sum(ml.ConditionNumber == i) > 0
            found = -1;
            for k = 1:npossibles
                for j = 1:nnames
                    if found < 0
                        if strcmp(ml.TaskObject{i, k}, nametable{j*2 - 1})
                            orinumbers = [orinumbers i nametable{j*2}];
                            found = 1;
                        end
                    end
                end
            end
        end
    end

    names = fieldnames(codes);
    oris = {};
    for i = 1:length(names)
        found = -1;
        for j = 1:length(orinumbers)/2
            if codes.(names{i}) == orinumbers(2*j - 1)
                oris.(names{i}) = orinumbers(2*j);
                found = 1;
            end
        end
        
        if found < 0
            oris.(names{i}) = -1;
        end
    end
    
    if isfield(oris, 'blank') && oris.blank >= 0
        warndlg('Blanks trials were showing stimuli');
    end
    
    if isfield(oris, 'plus') && oris.plus < 0
        warndlg('Plus trials were showing blank presentations');
    end
    
    if isfield(oris, 'neutral') && oris.neutral < 0
        warndlg('Neutral trials were showing blank presentations');
    end
    
    if isfield(oris, 'minus') && oris.minus < 0
        warndlg('Minus trials were showing blank presentations');
    end
    
    if isfield(oris, 'pavlovian') && oris.pavlovian < 0
        warndlg('Pavlovian trials were showing blank presentations');
    end
    
    if isfield(oris, 'pavlovian') && isfield(oris, 'plus') && oris.plus ~= oris.pavlovian
        warndlg('Plus and pavlovian trials were not showing the same stimuli');
        codes.pavlovian = 99;
    end
    
    if isfield(oris, 'plus') && isfield(oris, 'neutral') && oris.plus == oris.neutral
        warndlg('Plus and neutral trials were showing the same stimuli');
    end
    
    if isfield(oris, 'plus') && isfield(oris, 'minus') && oris.plus == oris.minus
        warndlg('Plus and minus trials were showing the same stimuli');
    end
    
    if isfield(oris, 'neutral') && isfield(oris, 'minus') && oris.neutral == oris.minus
        warndlg('Neutral and minus trials were showing the same stimuli');
    end
end
