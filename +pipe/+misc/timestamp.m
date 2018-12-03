function stamp = timestamp()
	% Returns the time and date as a string for run-level filenames
	current_time = clock;
	yr = sprintf('%02i', mod(current_time(1), 2000));
	mn = sprintf('%02i', current_time(2));
	dy = sprintf('%02i', current_time(3));

	hrs = sprintf('%02i', current_time(4));
	mins = sprintf('%02i', current_time(5));
	secs = sprintf('%02i', round(current_time(6)));

	stamp = [yr, mn, dy, '-', hrs, mins, secs];
end