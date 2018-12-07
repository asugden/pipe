function d = brainposition(mouse, date, run, server, fixed)
%registrationMovement returns the relative shift between frames.

    if nargin < 4, server = []; end
    if nargin < 5, fixed = 1; end

    d = [];
    try
        al = pipe.load(mouse, date, run, 'alignaffine', server);
    catch
        try
            al = pipe.load(mouse, date, run, 'alignxy', server);
        catch
            al = pipe.load(mouse, date, run, 'align', server);
        end
    end
    if isempty(al), return; end
    
    if ~isfield(al, 'trans')
        if isfield(al, 'T')
            if fixed
                dx = al.T(:, 1);
                dy = al.T(:, 2);
            else
                dx = diff(al.T(:, 1));
                dy = diff(al.T(:, 2));
            end
        end
    else
        if fixed
            dx = al.trans(:, 3);
            dy = al.trans(:, 4);
        else
            dx = diff(al.trans(:, 3));
            dy = diff(al.trans(:, 4));
        end
    end
        
    if isfield(al, 'tform')
        xtf = zeros(1, length(al.tform));
        ytf = zeros(1, length(al.tform));
        for i = 1:length(al.tform)
            xtf(i) = al.tform{i}.T(3, 1);
            ytf(i) = al.tform{i}.T(3, 2);
        end
        
        if fixed
            dx = dx + xtf';
            dy = dy + ytf';
        else 
            dx = dx + diff(xtf');
            dy = dy + diff(ytf');
        end
    end
    
    if fixed
        d = realsqrt(dx.^2 + dy.^2)';
    else
        d = [0 realsqrt(dx.^2 + dy.^2)'];
    end
end

