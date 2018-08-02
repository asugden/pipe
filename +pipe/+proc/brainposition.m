function d = brainposition(mouse, date, run, server, fixed)
%registrationMovement returns the relative shift between frames.

    if nargin < 4, server = []; end
    if nargin < 5, fixed = 1; end

    d = [];
    al = pipe.load(mouse, date, run, 'alignaffine', server);
    if isempty(al), al = pipe.load(mouse, date, run, 'alignxy', server); end
    if isempty(al), al = pipe.load(mouse, date, run, 'align', server); end
    if isempty(al), return; end
    
    if fixed
        dx = al.trans(:, 3);
        dy = al.trans(:, 4);
    else
        dx = diff(al.trans(:, 3));
        dy = diff(al.trans(:, 4));
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

