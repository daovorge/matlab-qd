classdef Keithley2600 < qd.classes.ComInstrument
    % Instrument driver for Keithley series 2600.
    %
    % If the keithley has several physical channels, instantiate one object
    % for each channel and change smu. E.g.
    %
    %   com = gpib('ni', 0, 1)
    %   fopen(com)
    %   a = Keithley2600()
    %   a.com = com
    %   a.smu = 'smua' % This is the default.
    %   b = Keithley2600()
    %   b.com = com
    %   b.smu = 'smub' % makes this instrument refer to the second channel.
    %
    % Note that com cannot be suplied to the Keithley2600 constructor as it
    % will attempt to open it (which will cause it to open twice).

    properties
        % Some keithley 2600s have several channels. This is the channel this
        % instrument refers to. The default is 'smua'.
        smu = 'smua'
        % ramp_rate.i is the ramp rate of the i channel in A/s and ramp_rate.v
        % is the ramp rate of the v channel in V/s. Default for both is []
        % which disables ramping.
        ramp_rate = struct('i', [], 'v', []);
        % ramp_step_size.i is the ramp step size of the i channel in A and
        % ramp_step_size.v is the ramp step size of the v channel in V.
        % Default is ramp_step_size.i = 1E-12 and ramp_step_size.v = 1E-9.
        ramp_step_size = struct('i', 1E-12, 'v', 1E-3);
        % Currently executing future or [].
        current_future
        limits = struct('i', [], 'v', []);
    end

    methods
        function obj = Keithley2600(varargin)
            % Keithley2600() or Keithley2600(com)
            %
            % If com is supplied, it should be a serial object which will be
            % opened. If you are making multiple instances of this class for
            % one physical instrument, set com manually on each instance. E.g.
            %
            %   com = gpib('ni', 0, 1)
            %   fopen(com)
            %   a = Keithley2600()
            %   a.com = com
            %   b = Keithley2600()
            %   b.com = com
            %   b.smu = 'smub' % makes this instrument refer to the second channel.
            obj = obj@qd.classes.ComInstrument(varargin{:});
        end

        function r = model(obj)
            r = 'Keithley 2600';
        end

        function r = channels(obj)
            r = {'i', 'v', 'r'};
        end

        function reset(obj)
            obj.sendf('%s.reset()', obj.smu);
        end

        function set_compliance(obj, i_or_v, level)
            obj.sendf('%s.source.limit%s = %.16f', obj.smu, i_or_v, level);
        end

        function turn_on_output(obj)
            obj.sendf('%s.source.output = 1', obj.smu);
        end

        function turn_off_output(obj)
            obj.sendf('%s.source.output = 0', obj.smu);
        end

        function set_NPLC(obj, nplc)
            obj.sendf('%s.measure.nplc = %.16f', obj.smu, nplc);
        end

        function val = getc(obj, channel)
            if not(isempty(obj.current_future))
                obj.current_future.resolve();
            end
            if not(ismember(channel, obj.channels))
                error('not supported.');
            end
            val = obj.querym('print(%s.measure.%s())', obj.smu, channel, '%f');
        end

        function future = setc_async(obj, channel, value)
            if not(isempty(obj.current_future))
                obj.current_future.resolve();
            end
            if not(ismember(channel, {'i', 'v'}))
                error('not supported.');
            end
            if ~isempty(obj.limits.(channel)) && abs(value)>obj.limits.(channel)
                error('Requested a value above the limit. Aborting. ins: %s, chan: %s, limit: %f, request: %f.', ...
                    obj.name, channel, obj.limits.(channel), value);
            end
            if isempty(obj.ramp_rate.(channel))
                obj.sendf('%s.source.level%s = %.16f', obj.smu, channel, value);
                future = qd.classes.SetFuture.do_nothing_future();
            else
                obj.current_future = ramp(obj, channel, value);
                future = obj.current_future;
            end
        end

        function set_limit(obj, channel, limit)
            % ins.set_limit(channel, limit)
            %
            % Set software limit for channel. Set the limit to [] to disable.
            if not(ismember(channel, {'i', 'v'}))
                error('not supported.');
            end
            obj.limits.(channel) = limit;
        end
    end

    methods(Access=private)
        function future = ramp(obj, channel, value)
            rate = obj.ramp_rate.(channel);
            step = obj.ramp_step_size.(channel);
            current_value = obj.querym('print(%s.source.level%s)', obj.smu, channel, '%f');
            count = ceil(abs((value - current_value)/step)) + 1;
            obj.sendf('%s.trigger.measure.action = %s.DISABLE', obj.smu, obj.smu);
            obj.sendf('%s.trigger.source.action = %s.ENABLE', obj.smu, obj.smu);
            obj.sendf('%s.trigger.endsweep.action = %s.SOURCE_HOLD', obj.smu, obj.smu);
            obj.sendf('%s.trigger.source.linear%s(%.16f, %.16f, %i)', obj.smu, channel, current_value, value, count);
            obj.sendf('%s.trigger.count = %i', obj.smu, count);
            obj.sendf('%s.source.delay = %.16f', obj.smu, step/rate);
            obj.sendf('%s.trigger.initiate()', obj.smu);
            function done = is_done()
                % Query the status of the instrument.
                r = obj.querym('print(bit.bitand(status.operation.sweeping.condition, status.operation.sweeping.%s));', ...
                    upper(obj.smu), '%f');
                done = r == 0.0;
            end
            function abort()
                if ~is_done()
                    obj.sendf('%s.abort()', obj.smu);
                    warning('%s: A ramp was aborted before it was finished.', obj.name);
                end
                obj.current_future = [];
            end
            function exec()
                while ~is_done()
                    pause(0.001);
                end
                obj.current_future = [];
            end
            future = qd.classes.SetFuture(@exec, @abort);
        end
    end
end

