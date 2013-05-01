classdef DecaDAC < qd.classes.FileLikeInstrument
    methods
        function obj = DecaDAC(port)
            obj.com = serial(port, ...
                'BaudRate', 9600, ...
                'Parity',   'none', ...
                'DataBits', 8, ...
                'StopBits', 1);
            fopen(obj.com); % will be closed on delete by FileLikeInstrument.
        end

        function r = model(obj)
            r = 'DecaDAC';
        end

        function r = channels(obj)
            r = qd.util.map(@(n)['CH' num2str(n)], 0:19);
        end

        function chan = channel(obj, id)
            n = qd.util.match(id, 'CH%d');
            if isempty(n)
                error('No such channel.');
            end
            chan = qd.ins.DecaDACChannel(n);
            chan.channel_id = id;
            chan.instrument = obj;
        end

        function r = describe(obj, register)
            r = obj.describe@qd.classes.FileLikeInstrument(register);
            r.current_values = struct();
            for q = obj.channels()
                r.current_values.(q{1}) = obj.getc(q{1});
            end
        end
    end
end