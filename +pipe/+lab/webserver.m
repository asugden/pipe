function path = webserver(clicked)
%WEBSERVER Path to cell-clicking webserver
    
    if nargin < 1
        clicked = false;
    end
    
    if clicked
        path = '\\tolman\webdata\clicked\';
    else
        path = '\\tolman\webdata\mousedata\';
    end

end

