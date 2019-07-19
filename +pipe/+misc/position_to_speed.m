function speed = position_to_speed(running, framerate)
%SBXSPEED Return the speed of a mouse running on a 3d printed wheel from
% date from the quadrature encoder
    
    wheel_diameter = 14; % in cm
    wheel_tabs = 44; 
    wheel_circumference = wheel_diameter*pi;
    step_size = wheel_circumference/(wheel_tabs*2);

    instantaneous_speed = zeros(length(running), 1);
    if ~isempty(instantaneous_speed)
        instantaneous_speed(2:end) = diff(running);
        instantaneous_speed(2) = 0;
        instantaneous_speed = instantaneous_speed*step_size*framerate; % Andrew fixed 190121, someone had changed framerate to fps
    end
    
    speed = conv(instantaneous_speed, ones(ceil(framerate/4), 1)/ceil(framerate/4), 'same')';
end

