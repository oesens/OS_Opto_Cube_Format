function Rita_Cube(participant_numner, monoc_eye)

if nargin < 2
    error('Rita_Cube(participant_numner, monoc_eye)')
end

%% Start
timestamp_start = GetTimestamp;

%% Toggles
p.USE_DIO = true;
p.USE_ARDUINO = true;
p.SKIP_AUDIO_PREPLAY = false;

%% Parameters
%paths
p.PATHS.FOLDER_ORDERS = ['.' filesep 'Orders' filesep];
p.PATHS.PATH_ORDER = sprintf('%sPAR%02d.xlsx', p.PATHS.FOLDER_ORDERS, participant_numner);
p.PATHS.FOLDER_DATA = ['.' filesep 'Data' filesep];
p.PATHS.PATH_SAVE = sprintf('%sPAR%02d_%s', p.PATHS.FOLDER_DATA, participant_numner, timestamp_start);
p.PATHS.FILEPATH_SIZE_FIRST = 'size_then_distance.mp3';
p.PATHS.FILEPATH_DISTANCE_FIRST = 'distance_then_size.mp3';
p.PATHS.FILEPATH_NOISE = 'Noise_10sec_0.1amp.wav';

%key names (to check a key's name, enter KbName in the command window and then press the key)
p.KEYS.CONTINUE.NAME = 'SPACE';
p.KEYS.CHANGE_BLOCK.NAME = 'RETURN'; %when block changes, must press this to continue
p.KEYS.EXIT.NAME = 'ESCAPE';
p.KEYS.FLAG.NAME = 'BACKSPACE';
p.KEYS.NEXT.NAME = 'N'; %skips to next block or to final cal

%timing
p.TIMING.SECONDS_OPTO_RECORD = 10;
p.TIMING.SECONDS_VIEW_OBJECT = 1;
p.TIMING.SECONDS_BETWEEN_INSTRUCTION_VIEW = 1; %time between instruciton audio ending and start of trial (goggle open, illum on, opto start, etc)
p.TIMING.SECONDS_LOOP_NOISE = 9;

%IO: DIO
p.IO.DIO.BOARD_NUMBER = 0;
% p.IO.DIO.RELEASE.PIN = 42;
p.IO.DIO.OPTO.PIN = 3;
p.IO.DIO.OPTO.HIGH = 1;
p.IO.DIO.OPTO.LOW = 0;
p.IO.DIO.GOGGLE.PIN = [1 2];
p.IO.DIO.GOGGLE.CLOSED = [0 0];
p.IO.DIO.GOGGLE.RIGHT = [1 0];
p.IO.DIO.GOGGLE.LEFT = [0 1];
p.IO.DIO.GOGGLE.BOTH = [1 1];

%IO: Arduino
% 2 3 4 7
p.IO.ARDUINO.LED.BLUE(1).LABEL = 'Large Rubik'; %top
p.IO.ARDUINO.LED.BLUE(1).PIN = 4;
p.IO.ARDUINO.LED.BLUE(1).BRIGHTNESS = 1;
p.IO.ARDUINO.LED.BLUE(2).LABEL = 'Small Rubik'; %2nd top
p.IO.ARDUINO.LED.BLUE(2).PIN = 3;
p.IO.ARDUINO.LED.BLUE(2).BRIGHTNESS = 1;
p.IO.ARDUINO.LED.BLUE(3).LABEL = 'Large Die'; %2nd bottom
p.IO.ARDUINO.LED.BLUE(3).PIN = 2;
p.IO.ARDUINO.LED.BLUE(3).BRIGHTNESS = 1;
p.IO.ARDUINO.LED.BLUE(4).LABEL = 'Small Die'; %bottom
p.IO.ARDUINO.LED.BLUE(4).PIN = 7;
p.IO.ARDUINO.LED.BLUE(4).BRIGHTNESS = 1;

%6 9
p.IO.ARDUINO.LED.LOC(1).LABEL = 'Near';
p.IO.ARDUINO.LED.LOC(1).PIN = 6;
p.IO.ARDUINO.LED.LOC(1).BRIGHTNESS = 255;
p.IO.ARDUINO.LED.LOC(2).LABEL = 'Far';
p.IO.ARDUINO.LED.LOC(2).PIN = 9;
p.IO.ARDUINO.LED.LOC(2).BRIGHTNESS = 255;

%5 8
p.IO.ARDUINO.LED.ILLUUM(1).LABEL = 'Near';
p.IO.ARDUINO.LED.ILLUUM(1).PIN = 5;
p.IO.ARDUINO.LED.ILLUUM(1).BRIGHTNESS = 255;
p.IO.ARDUINO.LED.ILLUUM(1).BRIGHTNESS_SMALL = 255;
p.IO.ARDUINO.LED.ILLUUM(1).BRIGHTNESS_LARGE = 255;

p.IO.ARDUINO.LED.ILLUUM(2).LABEL = 'Far';
p.IO.ARDUINO.LED.ILLUUM(2).PIN = 8;
p.IO.ARDUINO.LED.ILLUUM(2).BRIGHTNESS = 255;
p.IO.ARDUINO.LED.ILLUUM(2).BRIGHTNESS_SMALL = 255;
p.IO.ARDUINO.LED.ILLUUM(2).BRIGHTNESS_LARGE = 255;


p.IO.ARDUINO.INPUT.FOOT_BUTTON_POWER.PIN = 22;
p.IO.ARDUINO.INPUT.FOOT_BUTTON.PIN = 0; %analog in a0
p.IO.ARDUINO.INPUT.FOOT_BUTTON.THRESHOLD = 500;

p.IO.ARDUINO.INPUT.RELEASE_BUTTON_POWER.PIN = 26;
p.IO.ARDUINO.INPUT.RELEASE_BUTTON.PIN = 1; %analog in a1
p.IO.ARDUINO.INPUT.RELEASE_BUTTON.THRESHOLD = 500;

%sound
p.SOUND.LATENCY = .050;
p.SOUND.CHANNELS = 2;
p.SOUND.PLAY_FREQUENCY = 44100;
p.SOUND.BEEP_HIGH = repmat(MakeBeep(500, 0.25, p.SOUND.PLAY_FREQUENCY), [p.SOUND.CHANNELS 1]);
p.SOUND.BEEP_LOW = repmat(MakeBeep(300, 0.25, p.SOUND.PLAY_FREQUENCY), [p.SOUND.CHANNELS 1]);
p.SOUND.VOLUME = 1; %1 = 100%

%% Prepare

%Set Key Values
KbName('UnifyKeyNames');
for key = fields(p.KEYS)'
    key = key{1};
    eval(sprintf('p.KEYS.%s.VALUE = KbName(p.KEYS.%s.NAME);', key, key))
end

%Checks
if ~p.USE_DIO || ~p.USE_ARDUINO
    warning('Optotrak and/or Arduino disabled! Press %s to continue or %s to exit.', p.KEYS.CONTINUE.NAME, p.KEYS.EXIT.NAME)
    while 1
        [~,keys,~] = KbWait(-1);
        if keys(p.KEYS.EXIT.VALUE)
            error('Exit key pressed.')
        elseif keys(p.KEYS.CONTINUE.VALUE)
            break;
        end
    end
end

%Read Order
[~,~,xls] = xlsread(p.PATHS.PATH_ORDER);
d.order_info.first_vision = xls{1, 2};
d.order_info.order_raw = xls;
d.order = ParseOrder(xls(3:end, :));
d.number_trials = length(d.order);
d.trial_start_second_block = find(cellfun(@(x) ischar(x) & ~strcmp(x, d.order_info.first_vision), {d.order.vision}), 1, 'first');
d.trial_start_last_calibration = find(diff([d.order.is_calibration]) == 1, 1, 'last') + 1;
d.skip_to_options = [d.trial_start_second_block d.trial_start_last_calibration];

%Which eye for monoc
d.order_info.monoc_eye = lower(monoc_eye);
if strcmp(d.order_info.monoc_eye, 'right')
    p.IO.DIO.GOGGLE.MONOC = p.IO.DIO.GOGGLE.RIGHT;
elseif strcmp(d.order_info.monoc_eye, 'left')
    p.IO.DIO.GOGGLE.MONOC = p.IO.DIO.GOGGLE.LEFT;
else
    error('Unknown monoc eye! Should be left or right.')
end

%Create Folder(s)
if ~exist(p.PATHS.FOLDER_DATA, 'dir')
    mkdir(p.PATHS.FOLDER_DATA);
end

%IO: Arduino
if p.USE_ARDUINO
    ard = init_arduino('Mega 2560');
    
    %turn everything on to test connections
    ArduinoSetAll(ard, p, true)
    
    %turn on power to foot petal + release button
    ard.digitalWrite(p.IO.ARDUINO.INPUT.FOOT_BUTTON_POWER.PIN, 1);
    ard.digitalWrite(p.IO.ARDUINO.INPUT.RELEASE_BUTTON_POWER.PIN, 1);
else
    ard = nan;
end

%IO: DIO
if p.USE_DIO
    dio = digitalio('mcc', p.IO.DIO.BOARD_NUMBER);

    % Define line 1 to 40 as output
    addline(dio,0:7,1,'Out');	% First Port B
    addline(dio,0:7,4,'Out');	% Second Port A
    addline(dio,0:7,5,'Out');	% Second Port B
    addline(dio,0:3,2,'Out');	% First Port CL
    addline(dio,0:3,3,'Out');	% First Port CH
    addline(dio,0:3,6,'Out');	% Second Port CL
    addline(dio,0:3,7,'Out');	% Second Port CH

    % Define line 41 to 48 as input
    addline(dio,0:7,0,'In');     % First Port A

    % Set output to zeros for line 1 to 40
    putvalue(dio.line(1:8), [0 0 0 0 0 0 0 0]);
    putvalue(dio.line(9:16), [0 0 0 0 0 0 0 0]);
    putvalue(dio.line(17:24), [0 0 0 0 0 0 0 0]);
    putvalue(dio.line(25:28), [0 0 0 0]);
    putvalue(dio.line(29:32), [0 0 0 0]);
    putvalue(dio.line(33:36), [0 0 0 0]);
    putvalue(dio.line(37:40), [0 0 0 0]);
    
    %make sure opto starts low
    putvalue(dio.line(p.IO.DIO.OPTO.PIN), p.IO.DIO.OPTO.LOW);
    
    %open goggles
    SetGoggles(dio, p, p.IO.DIO.GOGGLE.BOTH)
else
    dio = nan;
end

%Prepare Sound
InitializePsychSound(1);

sound_handle = PsychPortAudio('Open', [], 1, [], p.SOUND.PLAY_FREQUENCY, p.SOUND.CHANNELS, [], p.SOUND.LATENCY);
PsychPortAudio('Volume', sound_handle, p.SOUND.VOLUME);

% sound_handle_beep_high = PsychPortAudio('Open', [], 1, [], p.SOUND.PLAY_FREQUENCY, p.SOUND.CHANNELS, [], p.SOUND.LATENCY);
% PsychPortAudio('FillBuffer', sound_handle_beep_high, p.SOUND.BEEP_HIGH);
% PsychPortAudio('Volume', sound_handle_beep_high, p.SOUND.VOLUME);

% sound_handle_beep_low = PsychPortAudio('Open', [], 1, [], p.SOUND.PLAY_FREQUENCY, p.SOUND.CHANNELS, [], p.SOUND.LATENCY);
% PsychPortAudio('FillBuffer', sound_handle_beep_low, p.SOUND.BEEP_LOW);
% PsychPortAudio('Volume', sound_handle_beep_low, p.SOUND.VOLUME);

[snd_size_first, f] = audioread(p.PATHS.FILEPATH_SIZE_FIRST);
snd_size_first = snd_size_first';
% [snd, f] = audioread(p.PATHS.FILEPATH_SIZE_FIRST);
% num_channel = size(snd,2);
% sound_handle_size_first = PsychPortAudio('Open', [], 1, [], f, num_channel, [], p.SOUND.LATENCY);
% PsychPortAudio('FillBuffer', sound_handle_size_first, snd');
% PsychPortAudio('Volume', sound_handle_size_first, p.SOUND.VOLUME);

[snd_distance_first, f] = audioread(p.PATHS.FILEPATH_DISTANCE_FIRST);
snd_distance_first = snd_distance_first';
% [snd, f] = audioread(p.PATHS.FILEPATH_DISTANCE_FIRST);
% num_channel = size(snd,2);
% sound_handle_distance_first = PsychPortAudio('Open', [], 1, [], f, num_channel, [], p.SOUND.LATENCY);
% PsychPortAudio('FillBuffer', sound_handle_distance_first, snd');
% PsychPortAudio('Volume', sound_handle_distance_first, p.SOUND.VOLUME);

[snd_noise, f] = audioread(p.PATHS.FILEPATH_NOISE);
snd_noise = snd_noise';
if size(snd_noise,1) < p.SOUND.CHANNELS
    snd_noise = repmat(snd_noise, [p.SOUND.CHANNELS 1]);
elseif size(snd_noise,1) > p.SOUND.CHANNELS
    snd_noise = snd_noise(1:p.SOUND.CHANNELS, :);
end

disp('Pre-playing audio for better latency later...')
if ~p.SKIP_AUDIO_PREPLAY
    for i = 1:1
        PsychPortAudio('FillBuffer', sound_handle, p.SOUND.BEEP_HIGH);
        PsychPortAudio('Start', sound_handle);
        PsychPortAudio('Stop', sound_handle, 1);
        WaitSecs(0.1);
        
        PsychPortAudio('FillBuffer', sound_handle, p.SOUND.BEEP_LOW);
        PsychPortAudio('Start', sound_handle);
        PsychPortAudio('Stop', sound_handle, 1);
        WaitSecs(0.1);
        
        PsychPortAudio('FillBuffer', sound_handle, snd_size_first);
        PsychPortAudio('Start', sound_handle);
        PsychPortAudio('Stop', sound_handle, 1);
        WaitSecs(0.1);
        
        PsychPortAudio('FillBuffer', sound_handle, snd_distance_first);
        PsychPortAudio('Start', sound_handle);
        PsychPortAudio('Stop', sound_handle, 1);
        WaitSecs(0.1);
        
%         PsychPortAudio('Start', sound_handle_beep_high);
%         PsychPortAudio('Stop', sound_handle_beep_high, 1);
%         WaitSecs(0.1);
%         PsychPortAudio('Start', sound_handle_beep_low);
%         PsychPortAudio('Stop', sound_handle_beep_low, 1);
%         WaitSecs(0.1);
%         PsychPortAudio('Start', sound_handle_size_first);
%         PsychPortAudio('Stop', sound_handle_size_first, 1);
%         WaitSecs(0.1);
%         PsychPortAudio('Start', sound_handle_distance_first);
%         PsychPortAudio('Stop', sound_handle_distance_first, 1);
%         WaitSecs(0.1);
    end
end

%Start Try
try
    
%% Start

fprintf(['-------------------------------------------------------------------\n\n' ...
         'Please check the following now:\n' ...
         '1. OTCollect duration is set to ' num2str(p.TIMING.SECONDS_OPTO_RECORD) ' seconds\n' ....
         '2. OTCollect is STARTED (PRESS START NOW)\n' ...
         '3. Goggles should be OPEN\n' ...
         '4. All LED should be ON\n' ...
         '\n' ...
         sprintf('Press %s to start or %s to exit...\n', p.KEYS.CHANGE_BLOCK.NAME, p.KEYS.EXIT.NAME) ...
         '\n-------------------------------------------------------------------\n'
         ])
while 1
    [~,keys,~] = KbWait(-1);
    if keys(p.KEYS.EXIT.VALUE)
        SetGoggles(dio, p, p.IO.DIO.GOGGLE.CLOSED)
        error('Exit key pressed.')
    elseif keys(p.KEYS.CHANGE_BLOCK.VALUE)
        break;
    end
end

%wait for continue key to lift
while 1
    [~,~,keys] = KbCheck(-1);
    if ~keys(p.KEYS.CONTINUE.VALUE)
        break;
    end
end

%lights off 
ArduinoSetAll(ard, p, false)
    
%% Trials

t0 = GetSecs;
time_allow_opto = 0;

trial_start_minus_one = 0; 

trial = 0 + trial_start_minus_one;
next_trial = 1 + trial_start_minus_one;

opto_counter = 0;

end_trial = false;
while trial < d.number_trials
    %increment trial number unless we are skipping to a specific trial
    if ~end_trial
        trial = trial + 1;
    end
    
    %default
    end_trial = false;
    d.trial_data(trial).completed = false;
    
    fprintf('Starting trial %d of %d...\n', trial, d.number_trials)
    
    % look for change in block
    if trial ~= 1 && (d.order(trial).is_calibration && ~d.order(trial-1).is_calibration)
        % start of calibration block
        fprintf('Calibration Block! Press %s to continue or %s to exit...\n', p.KEYS.CHANGE_BLOCK.NAME, p.KEYS.EXIT.NAME)
        
        %notify
        ArduinoSetAll(ard, p, true)
        
        %wait for key press to continue
        while 1
            [~,keys,~] = KbWait(-1);
            if keys(p.KEYS.EXIT.VALUE)
                error('Exit key pressed.')
            elseif keys(p.KEYS.CHANGE_BLOCK.VALUE)
                break;
            elseif keys(p.KEYS.NEXT.NAME)
                ind = find(d.skip_to_options > trial, 1, 'first');
                if ~isempty(ind)
                    WaitSecs(1);
                    [~,keys,~] = KbWait(-1);
                    if keys(p.KEYS.NEXT.NAME) %still pressed after a second
                        trial = d.skip_to_options(ind);
                        next_trial = trial;
                        end_trial = true;
                        fprintf('Skipping to trial: %d\n', trial);
                    end
                    break;
                end
            end
        end
        
    elseif ~d.order(trial).is_calibration && d.order(trial-1).is_calibration
        %change in vision condition = break
        fprintf('Start of trials! Press %s to continue or %s to exit...\n', p.KEYS.CHANGE_BLOCK.NAME, p.KEYS.EXIT.NAME)
        
        %notify
        ArduinoSetAll(ard, p, true)
        
        %wait for key press to continue
        while 1
            [~,keys,~] = KbWait(-1);
            if keys(p.KEYS.EXIT.VALUE)
                error('Exit key pressed.')
            elseif keys(p.KEYS.CHANGE_BLOCK.VALUE)
                break;
            elseif keys(p.KEYS.NEXT.NAME)
                ind = find(d.skip_to_options > trial, 1, 'first');
                if ~isempty(ind)
                    WaitSecs(1);
                    [~,keys,~] = KbWait(-1);
                    if keys(p.KEYS.NEXT.NAME) %still pressed after a second
                        trial = d.skip_to_options(ind);
                        next_trial = trial;
                        end_trial = true;
                        fprintf('Skipping to trial: %d\n', trial);
                    end
                    break;
                end
            end
        end
        
    elseif (~d.order(trial).is_calibration && ~d.order(trial-1).is_calibration) && ~strcmp(d.order(trial).vision, d.order(trial-1).vision)
        %change in vision condition = break
        fprintf('Change In Vision! Press %s to continue or %s to exit...\n', p.KEYS.CHANGE_BLOCK.NAME, p.KEYS.EXIT.NAME)
        
        %notify
        ArduinoSetAll(ard, p, true)
        
        %wait for key press to continue
        while 1
            [~,keys,~] = KbWait(-1);
            if keys(p.KEYS.EXIT.VALUE)
                error('Exit key pressed.')
            elseif keys(p.KEYS.CHANGE_BLOCK.VALUE)
                break;
            elseif keys(p.KEYS.NEXT.NAME)
                ind = find(d.skip_to_options > trial, 1, 'first');
                if ~isempty(ind)
                    WaitSecs(1);
                    [~,keys,~] = KbWait(-1);
                    if keys(p.KEYS.NEXT.NAME) %still pressed after a second
                        trial = d.skip_to_options(ind);
                        next_trial = trial;
                        end_trial = true;
                        fprintf('Skipping to trial: %d\n', trial);
                    end
                    break;
                end
            end
        end
        
    end
    
    if end_trial
        continue
    end
    
    %info
    d.trial_data(trial).condition = d.order(next_trial);
    next_trial = next_trial + 1; %may be overwritten by calibration flag
    fprintf('Trial %d of %d:\n', trial, d.number_trials)
    d.trial_data(trial).condition
    if trial < d.number_trials
        next_condition = d.order(next_trial);
    end

    %practice?
    is_practice = ~isempty(strfind(lower(d.trial_data(trial).condition.label), 'practice'));
    
    %open/close goggles
    if d.trial_data(trial).condition.is_calibration && ~is_practice
        SetGoggles(dio, p, p.IO.DIO.GOGGLE.BOTH)
    else
        SetGoggles(dio, p, p.IO.DIO.GOGGLE.CLOSED)
    end
    
    %set all all lights
    ArduinoSetAll(ard, p, false); %all off
    if ~d.trial_data(trial).condition.is_calibration
        %turn on required lights (blue and location)
        if p.USE_ARDUINO
            ind_loc = find(cellfun(@(x) strcmp(x, d.trial_data(trial).condition.location), {p.IO.ARDUINO.LED.LOC.LABEL}));
            loc = p.IO.ARDUINO.LED.LOC(ind_loc);
            ard.analogWrite(loc.PIN, loc.BRIGHTNESS);
            
            ind_blue = find(cellfun(@(x) strcmp(x, [d.trial_data(trial).condition.size ' ' d.trial_data(trial).condition.object]), {p.IO.ARDUINO.LED.BLUE.LABEL}));
            blue = p.IO.ARDUINO.LED.BLUE(ind_blue);
            ard.analogWrite(blue.PIN, blue.BRIGHTNESS);
        end
    end
    
    %loop noise while wait for start key
    PsychPortAudio('FillBuffer', sound_handle, snd_noise);
    WaitSecs(0.1);
    loop_time = 0;
    
    while 1
        if ~d.order(trial).is_calibration
            t = GetSecs;
            if t > loop_time
                PsychPortAudio('Stop', sound_handle);
                PsychPortAudio('Start', sound_handle);
                loop_time = t + p.TIMING.SECONDS_LOOP_NOISE;
            end
        end
        
        [~,~,keys] = KbCheck(-1);
        if keys(p.KEYS.EXIT.VALUE)
            error('Exit key pressed.')
        elseif keys(p.KEYS.CONTINUE.VALUE)
            
            fprintf('Starting trial...\n');
            
            %start trial
            break;
            
        elseif trial>1 && ~isempty(d.trial_data(trial-1).completed) && d.trial_data(trial-1).completed && ~d.trial_data(trial-1).flagged && keys(p.KEYS.FLAG.VALUE)
            
            %TODO: flag
        
        elseif keys(p.KEYS.NEXT.NAME)
            ind = find(d.skip_to_options > trial, 1, 'first');
            if ~isempty(ind)
                WaitSecs(1);
                [~,keys,~] = KbWait(-1);
                if keys(p.KEYS.NEXT.NAME) %still pressed after a second
                    trial = d.skip_to_options(ind);
                    next_trial = trial;
                    end_trial = true;
                    fprintf('Skipping to trial: %d\n', trial);
                end
                break;
            end
        end
    end
    PsychPortAudio('Stop', sound_handle); %stop static
    
    if end_trial
        continue
    end
    
    %lights off
    ArduinoSetAll(ard, p, false)
    
    %audio instruction
    if ~d.trial_data(trial).condition.is_calibration || is_practice
        if strcmp(d.trial_data(trial).condition.first_measure, 'Size')
            PsychPortAudio('FillBuffer', sound_handle, snd_size_first);
%             PsychPortAudio('Start', sound_handle_size_first);
%             PsychPortAudio('Stop', sound_handle_size_first, 1);
        elseif strcmp(d.trial_data(trial).condition.first_measure, 'Distance')
            PsychPortAudio('FillBuffer', sound_handle, snd_distance_first);
%             PsychPortAudio('Start', sound_handle_distance_first);
%             PsychPortAudio('Stop', sound_handle_distance_first, 1);
        else
            error('Unknown first measure (should be Distance or Size)!')
        end
        WaitSecs(0.1);
        PsychPortAudio('Start', sound_handle);
        PsychPortAudio('Stop', sound_handle, 1);
    
        %delay
        if p.TIMING.SECONDS_BETWEEN_INSTRUCTION_VIEW
            WaitSecs(p.TIMING.SECONDS_BETWEEN_INSTRUCTION_VIEW);
        end
    end
    
    %button
    fprintf('Waiting for button down...!\n')
    while 1

        %wait until button is down
        while ard.analogRead(p.IO.ARDUINO.INPUT.RELEASE_BUTTON.PIN) > p.IO.ARDUINO.INPUT.RELEASE_BUTTON.THRESHOLD
            [~,~,keys] = KbCheck(-1);
            if keys(p.KEYS.EXIT.VALUE)
                error('Exit key pressed.')
            end
        end

        fprintf('Button down. Waiting random delay...\n');

        %wait 0.5 to 1.0 seconds (random)
        WaitSecs(0.5 + rand/2);

        %if button is still down, break loop and start trial
        if ard.analogRead(p.IO.ARDUINO.INPUT.RELEASE_BUTTON.PIN) < p.IO.ARDUINO.INPUT.RELEASE_BUTTON.THRESHOLD
            break;
        else
            fprintf('Button did not remain down.\n');
        end

    end
    fprintf('Start!\n')
    
    %time start
    time_start = GetSecs;
    d.trial_data(trial).timing.start_relative_t0 = time_start - t0;
    
	%wait until button down if it was lifted immediately before
	while ard.analogRead(p.IO.ARDUINO.INPUT.RELEASE_BUTTON.PIN) > p.IO.ARDUINO.INPUT.RELEASE_BUTTON.THRESHOLD %while is up
		[~,~,keys] = KbCheck(-1);
		if keys(p.KEYS.EXIT.VALUE)
			error('Exit key pressed.')
		end
	end
	d.trial_data(trial).timing.start_button_down = GetSecs - time_start;
	
	%illum on
    if ~d.trial_data(trial).condition.is_calibration || is_practice
        if p.USE_ARDUINO
            ind_illum = find(cellfun(@(x) strcmp(x, d.trial_data(trial).condition.location), {p.IO.ARDUINO.LED.ILLUUM.LABEL}));
            ILLUUM = p.IO.ARDUINO.LED.ILLUUM(ind_illum);
            if is_practice
                ard.analogWrite(ILLUUM.PIN, ILLUUM.BRIGHTNESS);
            else
                if strcmp(d.trial_data(trial).condition.size, 'Small')
                    ard.analogWrite(ILLUUM.PIN, ILLUUM.BRIGHTNESS_SMALL);
                elseif strcmp(d.trial_data(trial).condition.size, 'Large')
                    ard.analogWrite(ILLUUM.PIN, ILLUUM.BRIGHTNESS_LARGE);
                end
            end
% % % % %             ard.analogWrite(ILLUUM.PIN, ILLUUM.BRIGHTNESS);
            d.trial_data(trial).timing.illum_on = GetSecs - time_start;
        end
    end
	
% %     %goggle open
% %     if ~d.trial_data(trial).condition.is_calibration
% %         if strcmp(d.trial_data(trial).condition.vision, 'Monoc')
% %             SetGoggles(dio, p, p.IO.DIO.GOGGLE.MONOC)
% %         elseif strcmp(d.trial_data(trial).condition.vision, 'Binoc')
% %             SetGoggles(dio, p, p.IO.DIO.GOGGLE.BOTH)
% %         end
% %         d.trial_data(trial).timing.goggle_open = GetSecs - time_start;
% %         need_close_goggles = true;
% %     else
% %         SetGoggles(dio, p, p.IO.DIO.GOGGLE.BOTH)
% %         
% %         if ~is_practice
% %             need_close_goggles = false;
% %         else
% %             need_close_goggles = true;
% %         end
% %     end
% %     %time_close_goggle = GetSecs + p.TIMING.SECONDS_VIEW_OBJECT;
    
    %google open (updated)
    if d.trial_data(trial).condition.is_calibration && ~is_practice
        %calibration (non-practice)
        SetGoggles(dio, p, p.IO.DIO.GOGGLE.BOTH)
        need_close_goggles = false;
    else
        %trial or practice
        if strcmp(d.trial_data(trial).condition.vision, 'Monoc')
            SetGoggles(dio, p, p.IO.DIO.GOGGLE.MONOC)
        elseif strcmp(d.trial_data(trial).condition.vision, 'Binoc')
            SetGoggles(dio, p, p.IO.DIO.GOGGLE.BOTH)
        end
        d.trial_data(trial).timing.goggle_open = GetSecs - time_start;
        need_close_goggles = true;
    end
    
	%wait until button up
	while ard.analogRead(p.IO.ARDUINO.INPUT.RELEASE_BUTTON.PIN) < p.IO.ARDUINO.INPUT.RELEASE_BUTTON.THRESHOLD %while is down
		[~,~,keys] = KbCheck(-1);
		if keys(p.KEYS.EXIT.VALUE)
			error('Exit key pressed.')
		end
	end
	d.trial_data(trial).timing.release_button = GetSecs - time_start;
	
	%opto
    time_opto = TriggerOpto(dio, p);
    d.trial_data(trial).timing.trigger_opto = time_opto - time_start;
    time_allow_opto = time_opto + p.TIMING.SECONDS_OPTO_RECORD + 1;
    opto_counter = opto_counter + 1;
    d.trial_data(trial).opto_counter = opto_counter;
	
	%close goggles
	SetGoggles(dio, p, p.IO.DIO.GOGGLE.CLOSED)
	d.trial_data(trial).timing.goggle_close = GetSecs - time_start;
	need_close_goggles = false;
	
	%illum off too
	if ~d.trial_data(trial).condition.is_calibration && p.USE_ARDUINO
		ard.analogWrite(ILLUUM.PIN, 0);
	end
	disp('Goggles cloed and illum off!')
	
	%set lights for next trial
	if trial < d.number_trials
		next_trial = trial + 1;
		
		if ~next_condition.is_calibration
			%turn on required lights (blue and location)
			if p.USE_ARDUINO
				ind_loc = find(cellfun(@(x) strcmp(x, next_condition.location), {p.IO.ARDUINO.LED.LOC.LABEL}));
				loc = p.IO.ARDUINO.LED.LOC(ind_loc);
				ard.analogWrite(loc.PIN, loc.BRIGHTNESS);

				ind_blue = find(cellfun(@(x) strcmp(x, [next_condition.size ' ' next_condition.object]), {p.IO.ARDUINO.LED.BLUE.LABEL}));
				blue = p.IO.ARDUINO.LED.BLUE(ind_blue);
				ard.analogWrite(blue.PIN, blue.BRIGHTNESS);
			end
			disp('Next lights set')
		end
		
	end
    
    %wait for response or out of time
    d.trial_data(trial).responses = 0;
    d.trial_data(trial).releases = 0;
    foot_down = false;
    releasing = false;
    d.trial_data(trial).flagged = false;
    PsychPortAudio('FillBuffer', sound_handle, p.SOUND.BEEP_HIGH);
    while GetSecs < time_allow_opto
        if p.USE_ARDUINO
            %foot pedal
            if ~foot_down && (ard.analogRead(p.IO.ARDUINO.INPUT.FOOT_BUTTON.PIN) > p.IO.ARDUINO.INPUT.FOOT_BUTTON.THRESHOLD)
                d.trial_data(trial).responses = d.trial_data(trial).responses + 1;
                d.trial_data(trial).timing.response(d.trial_data(trial).responses) = GetSecs - time_start;
                foot_down = true;
%                 PsychPortAudio('Start', sound_handle_beep_high);
                PsychPortAudio('Start', sound_handle);
                disp('Response!')
            elseif foot_down && (ard.analogRead(p.IO.ARDUINO.INPUT.FOOT_BUTTON.PIN) < p.IO.ARDUINO.INPUT.FOOT_BUTTON.THRESHOLD)
                foot_down = false;
%                 PsychPortAudio('Stop', sound_handle_beep_high);
                PsychPortAudio('Stop', sound_handle);
            end
            
            %release button
            if ~releasing
                if ard.analogRead(p.IO.ARDUINO.INPUT.RELEASE_BUTTON.PIN) > p.IO.ARDUINO.INPUT.RELEASE_BUTTON.THRESHOLD
                    d.trial_data(trial).releases = d.trial_data(trial).releases + 1;
                    d.trial_data(trial).timing.release(d.trial_data(trial).releases) = GetSecs - time_start;
                    disp('Released!')
                    %PsychPortAudio('Start', sound_handle);
                    releasing = true;
                else
                    releasing = false;
                    PsychPortAudio('Stop', sound_handle);
                end
            end
        end
        
% %         %release button
% %         if p.USE_DIO
% %             if getvalue(dio.line(p.IO.DIO.RELEASE.PIN))
% %                 if ~releasing
% %                     d.trial_data(trial).releases = d.trial_data(trial).releases + 1;
% %                     d.trial_data(trial).timing.release(d.trial_data(trial).releases) = GetSecs - time_start;
% %                     disp('Released!')
% %                     PsychPortAudio('Start', sound_handle);
% %                     releasing = true;
% %                 end
% %             else
% %                 releasing = false;
% %             end
% %         end
        
        %keys
        [~,~,keys] = KbCheck(-1);
        if keys(p.KEYS.EXIT.VALUE)
            error('Exit key pressed.')
        elseif ~d.trial_data(trial).flagged && keys(p.KEYS.FLAG.VALUE)
            warning('FLAGGED!')
            d.trial_data(trial).flagged = true;
            ArduinoSetAll(ard, p, true)
            
            %repeat if cal
            if d.trial_data(trial).condition.is_calibration
                d.number_trials = d.number_trials + 1;
                next_trial = trial;
                disp('Added repeat of calibration!')
            end
            
            %sound
            PsychPortAudio('FillBuffer', sound_handle, p.SOUND.BEEP_LOW);
            WaitSecs(0.1);
            for i = 1:3
                PsychPortAudio('Start', sound_handle);
                PsychPortAudio('Stop', sound_handle, 1);
                WaitSecs(0.1);
            end
            PsychPortAudio('FillBuffer', sound_handle, p.SOUND.BEEP_HIGH);
            
        end
    end
%     PsychPortAudio('Stop', sound_handle_beep_high, 1);
    PsychPortAudio('Stop', sound_handle, 1);
    
    %end of recording beep
    disp('End of recording beep!')
%     PsychPortAudio('Start', sound_handle_beep_low);
    PsychPortAudio('FillBuffer', sound_handle, p.SOUND.BEEP_LOW);
    WaitSecs(0.1);
    PsychPortAudio('Start', sound_handle);

    %save
    disp('Saving...')
    save(p.PATHS.PATH_SAVE, 'p', 'd')
    
    %end of trial
%     PsychPortAudio('Stop', sound_handle_beep_low, 1);
    PsychPortAudio('Stop', sound_handle, 1);
    
    d.trial_data(trial).completed = true;
end

%% End
save(p.PATHS.PATH_SAVE, 'p', 'd')
% PsychPortAudio('Close', sound_handle_beep_high);
PsychPortAudio('Close', sound_handle);
SetGoggles(dio, p, p.IO.DIO.GOGGLE.CLOSED)
ard.flush;
disp 'Done!'

%all lights flicker
for i = 1:5
    ArduinoSetAll(ard, p, true)
    WaitSecs(1);
    ArduinoSetAll(ard, p, false)
    WaitSecs(1);
end

%% Catch
catch err
%     PsychPortAudio('Close', sound_handle_beep_high);
    PsychPortAudio('Close');
    save(sprintf('Error_%s', timestamp_start))
    rethrow(err)
end

function [timestamp] = GetTimestamp
c = round(clock);
timestamp = sprintf('%d-%d-%d_%d-%d_%d',c([4 5 6 3 2 1]));

function [order] = ParseOrder(xls)
headers = xls(1,:);
num_col_use = find(cellfun(@ischar, headers), 1, 'last');
headers = headers(1:num_col_use);

order = [];
max_num_trial = size(xls, 1) - 1;
for trial = 1:max_num_trial
    row = trial + 1;
    if isnan(xls{row, 1})
        break;
    else
        for col = 1:num_col_use
            eval(sprintf('order(trial).%s = xls{row, col};', lower(headers{col})))
        end
    end
end

function ArduinoSetAll(ard, p, on)
if p.USE_ARDUINO
    for LED_type = fields(p.IO.ARDUINO.LED)'
        LED_type = LED_type{1};
        eval(sprintf('LED = p.IO.ARDUINO.LED.%s;', LED_type))
        for i = 1:length(LED)
            if isnan(LED(i).PIN)
                warning('PIN NOT SET')
            else
                if on
                    ard.analogWrite(LED(i).PIN, LED(i).BRIGHTNESS);
                else
                    ard.analogWrite(LED(i).PIN, 0);
                end
            end
        end
    end
end

function SetGoggles(dio, p, value)
if p.USE_DIO
    putvalue(dio.line(p.IO.DIO.GOGGLE.PIN), value);
end

function [time_opto] = TriggerOpto(dio, p)
if p.USE_DIO
    putvalue(dio.line(p.IO.DIO.OPTO.PIN), p.IO.DIO.OPTO.HIGH);
    time_opto = GetSecs;
    putvalue(dio.line(p.IO.DIO.OPTO.PIN), p.IO.DIO.OPTO.LOW);
else
    time_opto = GetSecs;
end

