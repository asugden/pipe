function hn = hostname(server)
%HOSTNAME Returns the system hostname, used for jobs.

    % Cache the hostname to accurately get the server
    persistent cached_hostname
    if ~isempty(cached_hostname)
        hn = cached_hostname;
    else
        [success, syshostname] = system('hostname');

        % some error checks
        assert(success == 0, 'Error running hostname');
        assert(~any(syshostname == '.'), 'Dots found in hostname: is it a fqdn?');

        hn = deblank(syshostname);
        cached_hostname = hn;
    end
end

