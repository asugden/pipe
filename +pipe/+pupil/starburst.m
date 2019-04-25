function [epx, epy, toolow] = starburst(I, cx, cy,...
    pupil_edge_thresh, N, minimum_candidate_features, inc_dec, verbose)

% Starburst Algorithm
%
% This source code is part of the starburst algorithm.
% Starburst algorithm is free; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.
%
% Starburst algorithm is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with cvEyeTracker; if not, write to the Free Software
% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
%
%
% Starburst Algorithm - Version 1.0.0
% Part of the openEyes ToolKit -- http://hcvl.hci.iastate.edu/openEyes
% Release Date:
% Authors : Dongheng Li <donghengli@gmail.com>
%           Derrick Parkhurst <derrick.parkhurst@hcvl.hci.iastate.edu>
% Copyright (c) 2005
% All Rights Reserved.

% Adapted by DHB 2017

% Input
% I = input image
% [cx cy] = central start point of the feature detection process
% pupil_edge_threshold = best guess for the pupil contour threshold
% N = number of rays
% minimum_candidate_features = must return this many features or error
% Ouput
% epx = x coordinate of feature candidates [row vector]
% epy = y coordinate of feature candidates [row vector]

if nargin < 7, inc_dec = 'inc'; end
if nargin < 8, verbose = false; end

% The anonymous function was slower than having the switch case each time
% in 2017 but NOT in 2015a: consider switching to it if you're using 2015a
% or check dynamically: strdouble of version('-release')
% a = zeros(1,2);
% b = zeros(1,2);
% Im = zeros(2);
% switch inc_dec
%     case 'dec'
%         get_d = @(Im, a, b) Im(a(2),a(1)) - Im(b(2),b(1));
%     case 'inc'
%         get_d = @(Im, a, b) Im(b(2),b(1)) - Im(a(2),a(1));
%     otherwise
%         warning('inc_dec must be inc or dec');
% end

toolow = false;

[height, width] = size(I);
dis = 1;
angle_spread = 100*pi/180;
loop_count = 0;
tcx(loop_count+1) = cx;
tcy(loop_count+1) = cy;
edge_thresh = pupil_edge_thresh;
angle_step= 2*pi/N;
min_edge_thresh = 4;

while edge_thresh > min_edge_thresh && loop_count <= 10
    epx = [];
    epy = [];
    while length(epx) < minimum_candidate_features && edge_thresh > min_edge_thresh
        [epx, epy, epd] = locate_edge_points(I, cx, cy, dis, angle_step, 0, 2*pi, edge_thresh, inc_dec);
        if length(epx) < minimum_candidate_features
            edge_thresh = edge_thresh - 1;
        end
    end
    if edge_thresh <= min_edge_thresh
        break;
    end
    
    angle_normal = atan2(cy-epy, cx-epx);
    for i=1:length(epx)
        [tepx, tepy, ~] = locate_edge_points(I, epx(i), epy(i), dis,...
            angle_step*(edge_thresh/epd(i)), angle_normal(i), angle_spread, edge_thresh, inc_dec);
        epx = [epx tepx];
        epy = [epy tepy];
    end
    
    loop_count = loop_count+1;
    tcx(loop_count+1) = mean(epx);
    tcy(loop_count+1) = mean(epy);
    if abs(tcx(loop_count+1)-cx) + abs(tcy(loop_count+1)-cy) < 10
        break;
    end
    cx = tcx(loop_count+1);
    cy = tcy(loop_count+1);
end

if loop_count > 10
    if verbose, fprintf(1, 'Error! edge points did not converge in %d iterations.', loop_count); end
    epx = []; epy = [];
    return;
end

if edge_thresh <= min_edge_thresh
    if verbose, fprintf(1, 'Error! Adaptive threshold is too low!\n'); end
    toolow = true;
    %     epx=[]; epy = [];
    return;
end


function [epx, epy, dir] = locate_edge_points(I, cx, cy, dis, angle_step, ...
    angle_normal, angle_spread, edge_thresh, inc_dec)

[height, width] = size(I);
epx = [];
epy = [];
dir = [];
ep_num = 0;  % ep stands for edge point
for angle=(angle_normal-angle_spread/2+0.0001):angle_step:(angle_normal+angle_spread/2)
    step = 2;
    p1 = [round(cx+dis*cos(angle)) round(cy+dis*sin(angle))];
    if p1(2) > height || p1(2) < 1 || p1(1) > width || p1(1) < 1
        continue;
    end
    while 1
        p2 = [round(cx+step*dis*cos(angle)) round(cy+step*dis*sin(angle))];
        if p2(2) > height || p2(2) < 1 || p2(1) > width || p2(1) < 1
            break;
        end
        
        switch inc_dec
            case 'dec'
                d = I(p1(2),p1(1)) - I(p2(2),p2(1));
            case 'inc'
                d = I(p2(2),p2(1)) - I(p1(2),p1(1));
            otherwise
                warning('inc_dec must be inc or dec');
        end
%         d = get_d(I, p1, p2);
        if (d >= edge_thresh)
            ep_num = ep_num+1;
            epx(ep_num) = p1(1);    % edge point x coordinate
            epy(ep_num) = p1(2);    % edge point y coordinate
            dir(ep_num) = d;
            break;
        end
        p1 = p2;
        step = step + 1;
    end
end



