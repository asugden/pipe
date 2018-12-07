function base = pathbase(server, jobdb_only)
%BASEPATH Hard codes the base data directories for the Andermann lab based
%   on servers and host names.

    % Cache the hostname to accurately get the server
    hn = pipe.misc.hostname();

    if nargin > 1 && jobdb_only && strcmpi(server, 'storage')
        server = hn;
    end
    
    % Set base path depending on server
    if nargin < 1 || isempty(server) || strcmpi(hn, server)
        if strcmpi(hn, 'Megatron')
            base = 'D:\twophoton_data\2photon\scan\';
        elseif strcmpi(hn, 'Atlas')
            base = 'E:\twophoton_data\2photon\raw\';
        elseif strcmpi(hn, 'beastmode')
            base = 'S:\twophoton_data\2photon\scan\';
        elseif strcmpi(hn, 'beastbaby')
            base = 'E:\twophoton_extra\2photon_extra\scan_extra\';
        elseif strcmpi(hn, 'Sweetness')
            base = 'D:\2p_data\scan\';
        elseif strcmpi(hn, 'santiago')
            base = 'D:\2p_data\scan\';
        end
    else
        if strcmpi(server, 'storage') && ~strcmpi(hn, 'megatron')
            base = '\\megatron\E\scan\';
        elseif strcmpi(server, 'storage')
            base = 'E:\scan\';
        elseif strcmpi(server, 'santiago')
            base = '\\santiago\2p_data\scan\';
        elseif strcmpi(server, 'sweetness')
            base = '\\sweetness\2p_data\scan\';
        elseif strcmpi(server, 'megatron')
            base = '\\megatron\2photon\scan\';
        elseif strcmpi(server, 'anastasia')
            base = '\\anastasia\data\2p\';
        elseif strcmpi(server, 'atlas')
            base = '\\atlas\twophoton_data\2photon\raw\';
        elseif strcmpi(server, 'beastmode')
            base = '\\beastmode\twophoton_data\2photon\scan\';
        elseif strcmpi(server, 'beastbaby')
            base = '\\beastmode\E\twophoton_extra\2photon_extra\scan_extra\';
        end
    end
end

