function nidaq = read_sbxephys(mouse, date, run, server, rig, interpolate2p)
    % The number of Ephys channels is not saved anywhere, so we have to
    % guess. The lab has always used 7, 8, or 9 channels. So, we will
    % estimate from that.
    
    % Input channels
    starsky = struct( ...  % Matching channels for Icarus
        'frames2p', 2, ...
        'quinine', 3, ...
        'photometry1', 4, ...
        'ensure', 5, ...
        'licking', 6, ...
        'visstim', 7, ...
        'photometry2', 9 ...
    );

    hutch = struct( ...
        'frames2p', 6, ...
        'quinine', 9, ...
        'ensure', 3, ...
        'licking', 4, ...
        'visstim', 2 ...
    );

    %% Find the ephys file if possible
    if nargin < 5, rig = []; end
    if nargin < 6, interpolate2p = true; end
    if nargin < 3
        epath = mouse;
        infpath = [epath(1:end-6) '.sbx'];
        if nargin == 2, rig = date; end
    else
        if nargin < 4, server = []; end
        epath = pipe.path(mouse, date, run, 'ephys', server);
        infpath = pipe.path(mouse, date, run, 'sbx', server);
    end
    
    % Get the number of frames and scan rate
    info = pipe.io.sbxInfo(infpath);    
    freq = 2000;
    
    %% Open the ephys file and read
    ephys = fopen(epath);
    data = fread(ephys, 'float');
    fclose(ephys);
    
    convert_to_sec = length(data)./freq;
    length_mov = info.nframes./info.framerate;
    nchannels = round(convert_to_sec./length_mov);
    
    % Remove the initial quiet period that is dependent on the number of
    % channels recorded
    convert_to_sec = convert_to_sec - 1.5*nchannels;
    length_mov = info.nframes./info.framerate;
    nchannels = round(convert_to_sec./length_mov);

    if nchannels > 12
        warndlg('More than 12 channels, tell Arthur');
        freq = 1000;
        convert_to_sec = length(data)./freq;
        nchannels = round(convert_to_sec./length_mov);
    end
    
    if nchannels < 6
        freq = 1000;
        convert_to_sec = length(data)./freq;
        nchannels = round(convert_to_sec./length_mov);
    end
    
    %% Unshuffle the data
    sz = size(data');
    data = reshape(data', nchannels, sz(2)/nchannels); 
    
    % And return as struct
    nidaq.data = data';
    nidaq.timeStamps = ((1:size(nidaq.data, 1)) - 1)'./freq;
    nidaq.Fs = freq;
    nidaq.nframes = info.nframes;
    
    %% Estimate which rig is being used
    if isempty(rig)
        if length(find(diff(nidaq.data(:, hutch.frames2p) > 2.5) == 1)) > ...
                length(find(diff(nidaq.data(:, hutch.visstim) > 2.5) == 1))
            rig = 'hutch';
        end
    end
    if isempty(rig)
        rig = 'starsky/icarus';
    end
    
    % Set the channels based on username and rig
    nidaq.rig = rig;
    if strcmp(rig, 'hutch')
        nidaq.channels = hutch;
    else
        nidaq.channels = starsky;
    end
    
    % Add all channels to output
    channelnames = fieldnames(nidaq.channels);
    for i = 1:length(channelnames)
        if nidaq.channels.(channelnames{i}) <= nchannels
            nidaq.(channelnames{i}) = nidaq.data(:, nidaq.channels.(channelnames{i}))';
        end
    end
    
    %% Interpolate 2p frames if necessary
    
    if interpolate2p
        ind = find(diff(nidaq.frames2p > 2.5) == 1); % Rising edge
        if length(ind) < info.nframes*(4.0/5)
            warndlg('Interpolating 2p frames');
            
            ipi = diff(ind);
            % Tried to calculate it, but we were missing too many pulses. Had
            % to hardcode
            pulsewidth = round(129.0/2000*nidaq.Fs);

            % Add in pulses in between
            for p = 1:length(ind)-1
                between = round(ipi(p)/pulsewidth);
                for i = 1:between-1
                    ptime = round(ipi(p)/between);
                    nidaq.frames2p(ind(p) + i*ptime:ind(p) + i*ptime + 4) = 5;
                end
            end

            % Add in pulses at the end, if necessary
            ind = find(diff(nidaq.frames2p > 2.5) == 1);
            while info.nframes - length(ind) > 0 && length(nidaq.frames2p) - ...
                    ind(end) - pulsewidth > 900/2000*nidaq.Fs
                nidaq.frames2p(ind(end) + pulsewidth:ind(end) + pulsewidth + 4) = 5;
                ind = find(diff(nidaq.frames2p > 2.5) == 1);
            end

            % Add in pulses at the beginning if there are any left over
            while info.nframes - length(ind) > 0
                nidaq.frames2p(ind(1) - pulsewidth:ind(1) - pulsewidth + 4) = 5;
                ind = find(diff(nidaq.frames2p > 2.5) == 1);
            end
        end
    end
end