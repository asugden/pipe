function masks(mouse, date, runs, server, force)
%SBXPUPILMASKS Generate pmask files with pupil masks for automated pupil
%   detection

    if nargin < 4, server = []; end
    if nargin < 3 || isempty(runs), runs = pipe.lab.runs(mouse, date, server); end
    if nargin < 5, force = false; end

    % Make the pupil premasks so that they can be loaded quickly
    pipe.pupil.premasks(mouse, date, runs, server);
    
    version = 2;
    bwmask = [];
    
    for run = runs
        sbxpath = pipe.path(mouse, date, run, 'sbx', server);
        
        saverun = false;
        if ~isempty(sbxpath)
            avim = [sbxpath(1:end-4) '-totalpupil.tif'];
            im500s = [sbxpath(1:end-4) '-im500s.tif'];
            
            run_masks = true;
            missing_bwmask = true;
            missing_cxcy = true;
            
            save_path = pipe.path(mouse, date, run, 'pmask', server, 'estimate', true);
            if exist(save_path) && ~force
                pmask = load(save_path, '-mat');
                if isfield(pmask, 'version') && pmask.version >= 2
                    run_masks = false;
                else
                    if isfield(pmask, 'bwmask')
                        missing_bwmask = false;
                        bwmask = pmask.bwmask;
                    end
                    
                    if isfield(pmask, 'cx') && isfield(pmask, 'cy')
                        missing_cxcy = false;
                        cx = pmask.cx;
                        cy = pmask.cy;
                    end
                end
            end

            if run_masks
                % First, get the masks
                im = pipe.io.read_tiff(avim);

                if missing_bwmask
                    if ~isempty(bwmask)
                        temp = figure;
                        subplot(1, 2, 1);
                        imagesc(im);
                        colormap('Gray');
                        subplot(1, 2, 2);
                        imagesc(im.*bwmask);
                        colormap('Gray');
                        button = questdlg('Does the previous mask overlap with the pupil?', ...
                            'No', 'Yes');
                        if strcmp(button, 'No')
                            bwmask = [];
                        end
                        close(temp);
                    end

                    if isempty(bwmask)
                        % uiwait(msgbox('Click in an outline around the visible eyeball. Double click within to finish.'));
                        figure;
                        title('Click around eyeball. Double-click to finish.');
                        bwmask = roipoly(im);
                    end
                end

                % Then, get the cx, cy
                eyes = pipe.io.read_tiff(im500s);
                if missing_cxcy
                    imagesc(eyes(:, :, 1), [0 100]);
                    title('Select the center of the eye');
                    [cx, cy] = ginput(1);
                    close(gcf());
                end
                
                % Finally, find the times when the eye is closed
                eyes = pipe.proc.binxy(eyes, 4);
                
                info = pipe.metadata(sbxpath);
                cols = 10;
                rows = ceil(size(eyes, 3)/cols);
                sz = size(eyes);
                comb_images = zeros(rows*sz(1), cols*sz(2));
                
                skip = logical(zeros(1, size(eyes, 3)));
                for r = 1:rows
                    for c = 1:cols
                        imn = (r-1)*cols + c;
                        if imn <= size(eyes, 3)
                            comb_images((r-1)*sz(1)+1:r*sz(1), (c-1)*sz(2)+1:c*sz(2)) = ...
                                eyes(:, :, imn);
                        end
                    end
                end
                
                sleep = figure;
                imagesc(comb_images);
                colormap('Gray');
                title('Click on closed eyes. Enter to close.');
                hold on;
                button = 1;
                while button <= 3   % read ginputs until a mouse right-button occurs
                    try
                        [x, y, button] = ginput(1);
                    catch
                        break;
                    end
                    
                    c = ceil(x/sz(2));
                    r = ceil(y/sz(1));
                    imn = (r - 1)*cols + c;
                    if imn <= length(skip)
                        skip(imn) = 1 - skip(imn);
                    
                        bw_mask = ones(size(comb_images, 1), size(comb_images, 2));
                        for r = 1:rows
                            for c = 1:cols
                                imn = (r-1)*cols + c;
                                if imn <= size(eyes, 3) && skip(imn)
                                    bw_mask((r-1)*sz(1)+1:r*sz(1), (c-1)*sz(2)+1:c*sz(2)) = 0;
                                end
                            end
                        end
                    end
                    
                    imagesc(comb_images.*bw_mask);
                end
                
                try
                    close(sleep);
                end
                
                sleep_mask = logical(zeros(1, info.nframes));
                for s = 1:length(skip)
                    if skip(s)
                        sleep_mask((s-1)*500 + 1:s*500) = 1;
                    end
                end
                
                save(save_path, 'bwmask', 'cx', 'cy', 'sleep_mask', 'version');
            end
        end
    end
end

