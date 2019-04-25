function premasks(mouse, date, runs, server)
%SBXPUPILMASKS Generate pmask files with pupil masks for automated pupil
%   detection

    if nargin < 4, server = []; end
    if nargin < 3 || isempty(runs), runs = pipe.lab.runs(mouse, date, server); end
    
    bin_images = 500;

    for run = runs
        sbxpath = pipe.path(mouse, date, run, 'sbx', server);
        
        if ~isempty(sbxpath)
            avim = [sbxpath(1:end-4) '-totalpupil.tif'];
            im500s = [sbxpath(1:end-4) '-im500s.tif'];
            
            if ~exist(avim) || ~exist(im500s)
                eye = pipe.load(mouse, date, run, 'pupil', server);  % Could be path = sbxPath(mouse, date, run, 'avi'), then read as matrix

                if isfield(eye, 'data')
                    eye = squeeze(eye.data);  % This is a matrix

                    % Get the best image for determining the outline and get the mask
                    av = mean(eye, 3);
                    av = av - min(min(av));
                    av = av/max(max(av));

                    mx = double(max(eye, [], 3));
                    mx = mx - min(min(mx));
                    mx = mx/max(max(mx));

                    % Combine average and max to find the mask
                    both = (av + mx)/2;
                    pipe.io.write_tiff(both, avim, class(both));
                    
                    bin_mov = pipe.proc.bint(double(eye), bin_images);
                    bin_mov = bin_mov - min(min(min(bin_mov)));
                    bin_mov = bin_mov/max(max(max(bin_mov)))*255;
                    pipe.io.write_tiff(uint8(bin_mov), im500s);
                end
            end
        end
    end
end

