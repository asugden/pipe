function out = sum_intensities(pupil, bwmask, framerate, lowpass)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

    % Apply the mask and sum
    masked = bsxfun(@times, bwmask, double(squeeze(pupil)));
    out = squeeze(sum(sum(masked, 2), 1));
    out = out./sum(sum(bwmask));
    
    % Find deviations that are too large
    stdev = std(out);
    bl = medfilt1(out, 100);
    out(out > bl + 2*stdev) = -1;
    out(out < bl - 2*stdev) = -1;
    
    % Fix beginning
    out(1) = out(2); % Fix errors on first frame
    if sum(out(1:3) == -1) > 0
        epos = 3 + find(out(4:end) > -1, 1) - 2;
        out(1:epos) = out(epos + 2);
    end
    
    % Interpolate across -1 regions
    npos = 3 + find(out(4:end - 4) == -1, 1);
    while ~isempty(npos)
        epos = npos + find(out(npos:end - 4) > -1, 1) - 2;
        
        if isempty(epos)
            out(npos - 2:end) = out(npos - 3);
        else
            while epos + 5 < length(out) && ~isempty(find(out(epos+1:epos+5) == -1, 1))
                epos = epos + find(out(epos+3:end - 4) > -1, 1) + 2;
                if isempty(epos), epos = length(out); end
            end
            
            % No idea what this does- fixing error
            if epos + 3 > length(out), epos = length(out) - 3; end
            
            binterp = out(npos - 3);
            einterp = out(epos + 3);
            
            ninterp = (epos + 2) - (npos - 2) + 1;
            newdata = interp1([0 ninterp + 1], [binterp einterp], 1:ninterp);
            out(npos - 2:epos + 2) = newdata';
        end
        
        npos = npos + find(out(npos:end - 4) == -1, 1) - 1;
    end
    
    % Lowpass filter if necessary
    if lowpass
        d = designfilt('lowpassiir', ...
        'PassbandFrequency',1, 'StopbandFrequency',3, ...
        'PassbandRipple',0.2, 'StopbandAttenuation',60, ...
        'SampleRate', framerate);
        
        out = filtfilt(d, out);
    end
end

