function Reverberant_MSR_Analysis_batchfunc( setups, room_setup, signal_types, weight, mask_level, pesqNumber, RecordingType)
%% Initialise
tic;
% Start Parallel Pool
para_pool = parpool;
C = clock;
fprintf('Started execution at %.0f:%.0f:%.0f on the %.0f/%.0f/%.0f\n',C([4:6 3:-1:1]))

if nargin < 7
    RecordingType = 'simulated';
end

%% Setup and Path Info
Drive = 'Z:\'; % Database drive (storage drive)

%LUT_resolution =  '512f_256w'; %Look-Up Table resolution
LUT_resolution =  '512f_32w'; %Look-Up Table resolution
signal_info.c = 343; % Speed of sound in metres/sec
signal_info.Fs = 16000; % Sampling frequency
signal_info.Nfft = 1024;% Number of fft components
signal_info.overlap = 0.5;
signal_info.f_low  = 150;  % Hz
signal_info.f_high = 8000; % Hz
signal_info.weight = weight;
signal_info.L_noise_mask = mask_level; % dB
signal_info.input_filename = [];
signal_info.recording_type = RecordingType;

signal_type = [signal_types{2:end}];
if length(signal_types) >= 3
    signal_type = ['Hybrid' signal_type];
end
signal_info.method = signal_type;


if nargin < 5
   signal_info.L_noise_mask = [];
end
if nargin < 6
    pesqNumber = 0;
end

sc = '_'; % Separating character for ascii paths

%% Obtain Recordings and Results Directory Path
ResultsPath = Results.getResultsPath( setups{1}, LUT_resolution, room_setup, signal_info, Drive );
if ~exist(ResultsPath,'dir'); mkdir(ResultsPath); end
save([ResultsPath 'Setups.mat'], 'setups');

levels = signal_info.L_noise_mask;
Recordings_Path = cell(length(levels),length(setups));

if strcmpi(RecordingType,'simulated')
    s_1 = 1;
elseif strcmpi(RecordingType,'realworld')
    s_1 = 2;
end

for s = s_1:length(setups)
    signal_info.method = signal_types{s};
    if isempty(strfind( signal_types{s}, 'Parametric' )) % If not parametric
        signal_info.weight = weight;
    else % If parametric
        signal_info.weight = 1;
    end
    for m = 1:length(levels)
        if s == 1
            signal_info.L_noise_mask = -Inf; %Masker level is non-existent for setup one (speech setup)
        else
            signal_info.L_noise_mask = levels(m);
        end
        if strcmpi(RecordingType,'simulated')
            Recordings_Path{m,s} = Results.getRecordingsPath( setups{s}, LUT_resolution, room_setup, signal_info, Drive );
        elseif strcmpi(RecordingType,'realworld')
            Recordings_Path{m,s} = Hardware_Control.getRealRecordingsPath( setups{1}, LUT_resolution, room_setup, signal_info, Drive );
        end
    end
end
signal_info.L_noise_mask = levels;
signal_info.weight = weight;
signal_info.method = signal_type;


%% Delete previous results file
Results.deleteResultsFile( ResultsPath, {'PESQ', 'STOI', 'SNR'});

%% Start Evaluation Loop
fprintf('\n====== Analysing Simulated Reverberant Signals ======\n');
fprintf(['            Room Size: ' [strrep(sprintf(strrep(repmat('%g',1,length(room_setup.Room_Size)),'g%','g %'),room_setup.Room_Size),' ','m x ') 'm'] '\n']);
fprintf(['Wall Absorption Coeff: ' num2str(room_setup.Wall_Absorb_Coeff) '\n']);
fprintf([' Virtual Source Angle: ' num2str(setups{1}.Multizone_Soundfield.Bright_Zone.SourceOrigin.Angle) '\n']);
fprintf(['    Privacy Weighting: ' signal_info.method '\n\n']);n=0;h=[];
fprintf('\tCompletion: ');


%% Find Speaker Signals and read to Workspace
M = length(signal_info.L_noise_mask);
S = length(setups);
for m = 1:M
    
    for s=s_1:S
        files_ = Tools.getAllFiles( Recordings_Path{m,s} );        
        files = {[],[]};
        files{:,s} = sort(files_);
    end
    
    fileName_prev = '';
    Rec_Bright = [];
    Rec_Quiet = [];
    
    for s=2:S
        fileName={};
        fpos = [1 (s_1+1)];
        for f=fpos
            [~, fileName{s,f}, ~] = fileparts(files{s}{f});
        end
        % These should be maskers unless realworld recording
        Rec_Bright_{s} = load(files{s}{fpos(1)});
        Rec_Quiet_{s} = load(files{s}{fpos(2)});
        if isfield(Rec_Bright_{s},'fs')
            Fs = Rec_Bright_{s}.fs;
        else
            Fs = signal_info.Fs;
        end
    end
%     if S == 3 % If two maskers are found
%         [Rec_Bright_, Rec_Quiet_] = adjustHybridMaskers( ...
%             Rec_Bright_, Rec_Quiet_, setups, signal_info);
%     end
    
    F = size(files{s_1},1);
    for file = 1:F
            
        [~, fileName{s_1,file}, ~] = fileparts(files{s_1}{file});
        
        
        if isempty(strfind(fileName{s_1,file},'Original')) % Make sure the file being read isn't an original file
            
            % Get the file number and file name
            [Ztypeflip,Stypeflip] = strtok( flip(fileName{s_1,file}), sc );
            SignalName = flip( Stypeflip );
            ZoneType = flip( Ztypeflip );

            
            if ~(isempty(fileName_prev) || strcmp( SignalName, fileName_prev))
                Rec_Bright = [];
                Rec_Quiet = [];
            end
            
            if strcmp('Bright',ZoneType)
                Rec_Bright = [];
                Rec_Bright_{s_1} = load(files{s_1}{file});
                if s_1==2, Rec_Bright_{s_1}.Rec_Sigs_B = Rec_Bright_{s_1}.Rec_Sigs_B'; end; %TODO: Fix the recording so the dimensions are in the correct place.
                sigLen = size( Rec_Bright_{s_1}.Rec_Sigs_B,2);
                for s=s_1:S
                    Rec_Bright(:,:,s) = Rec_Bright_{s}.Rec_Sigs_B(:,1:sigLen);
                end
                Rec_Bright = sum( Rec_Bright, 3 );
            elseif strcmp('Quiet',ZoneType)
                Rec_Quiet = [];
                Rec_Quiet_{s_1} = load(files{s_1}{file});
                if s_1==2, Rec_Quiet_{s_1}.Rec_Sigs_Q = Rec_Quiet_{s_1}.Rec_Sigs_Q'; end; %TODO: Fix the recording so the dimensions are in the correct place.
                sigLen = size( Rec_Quiet_{s_1}.Rec_Sigs_Q,2);
                for s=s_1:S
                    Rec_Quiet(:,:,s) = Rec_Quiet_{s}.Rec_Sigs_Q(:,1:sigLen);
                end
                Rec_Quiet = sum( Rec_Quiet, 3 );
            else
                error('Error reading the recordings. The type of zone read from the file name is not supported');
            end
            
            if all( [any(Rec_Bright(:)), any(Rec_Quiet(:))] ) % If we have two complete group of receiver signals for each zone
                
                % Read original file
                for file_orig = 1:F
                    if ~isempty( strfind(files{s_1}{file_orig}, [SignalName 'Original']) )
                        break
                    end
                end
                try
                    orig = audioread( files{s_1}{file_orig} );
                catch err
                    if strcmp(err.identifier, 'MATLAB:audiovideo:audioread:FileTypeNotSupported')
                        continue; % Skip unsupported files
                    end
                end
                
                
                % BEGIN Downsample realworld recordings
                if Fs ~= signal_info.Fs
                    down_rate = Fs / signal_info.Fs ;
                    Rec_Bright_down = zeros(ceil(size(Rec_Bright).*[1 1/down_rate]));
                    Rec_Quiet_down = zeros(ceil(size(Rec_Quiet).*[1 1/down_rate]));
                    for  r = 1:size(Rec_Bright,1)
                        Rec_Bright_down(r,:) = ...
                            decimate( Rec_Bright(r,:), down_rate );
                        Rec_Quiet_down(r,:) = ...
                            decimate( Rec_Quiet(r,:), down_rate );
                    end
                    Rec_Bright = Rec_Bright_down;
                    Rec_Quiet  = Rec_Quiet_down ;
                    if ~isempty(orig)
                        orig = decimate( orig, down_rate );
                    end
                end
                % END Downsample realworld recordings
                
                
                % BEGIN Resize the original speech signal and
                % Align it with the reverberant signals.
                orig(length(orig):size(Rec_Bright,2))=0; % Resize the original signal because the reverberant signal will be longer
                if (length(orig) ~= length(Rec_Bright)) || (length(orig) ~= length(Rec_Quiet))
                    error('Size of the original signal does not match the reproduced signal!');
                end
                
                %c_speed = 343;%343m/s speed of sound in air
                %max_delay = speaker_radius*2 / c_speed * signal_info.Fs;
                max_delay = signal_info.Fs / 2;
                Original = zeros(size(Rec_Bright,1),2,length(orig));
                                
                for r = 1:size(Rec_Bright,1)
                    delay = sigalign(Rec_Bright(r,:), orig, [-1 1]*max_delay) - 1;
                    if delay <= 0
                        Original(r,1,:) = [orig(-delay:end); zeros(-delay-1,1)];
                    elseif delay>0
                        Original(r,1,:) = orig;
                        Rec_Bright(r,:) = [Rec_Bright(r,delay:end), zeros(1,delay-1)];
                    end
                    
                    delay = sigalign( Rec_Quiet(r,:), orig, [-1 1]*max_delay) - 1;
                    if delay <= 0
                        Original(r,2,:) = [orig(-delay:end); zeros(-delay-1,1)];
                    elseif delay>0
                        Original(r,2,:) = orig;
                        Rec_Quiet(r,:) = [Rec_Quiet(r,delay:end), zeros(1,delay-1)];
                    end
                end
                % END resize and align                
                
                % BEGIN Calculate and save results
                
                % Perceptual Evaluation of Speech Quality
                Room_Acoustics.Apply_RIRs.Save_Reverb_PESQ_Result( Original, Rec_Bright, signal_info.Fs, signal_info.L_noise_mask(m), ResultsPath, [], SignalName, pesqNumber );
                
                % Speech Intelligibility
                % STOI
                Room_Acoustics.Apply_RIRs.Save_Reverb_STOI_Result( Original, Rec_Bright, Rec_Quiet, signal_info.Fs, signal_info.L_noise_mask(m), ResultsPath, [], SignalName );
                % STI
                %Room_Acoustics.Apply_RIRs.Save_Reverb_STI_Result( Original, Rec_Bright, Rec_Quiet, signal_info.Fs, ResultsPath, [], SignalName{1} );
                
                % Signal to Noise Ratio
                Room_Acoustics.Apply_RIRs.Save_Reverb_SNR_Result( Original, Rec_Bright, Rec_Quiet, signal_info.Fs, signal_info.L_noise_mask(m), ResultsPath, [], SignalName );
                
                % END calc and save results
                
            end
            
            fileName_prev = SignalName;
            
        end
        
        [n,h] = Tools.showTimeToCompletion( ((m-1)*F + file)/ (F*M), n, h);
        
    end
end

%%
tEnd = toc;
fprintf('\nExecution time: %dmin(s) %fsec(s)\n\n', floor(tEnd/60), rem(tEnd,60)); %Time taken to execute this script

% Delete Parallel Pool
delete(para_pool);

end

function [Rec_B, Rec_Q] = adjustHybridMaskers(Rec_B, Rec_Q, Setups, SigInfo) % Assumes two maskers only
% Find cutoff from multizone setup
S = Setups{1};
BZ = S.Multizone_Soundfield.Bright_Zone;
QZ = S.Multizone_Soundfield.Quiet_Zone;
R_ = max( [BZ.Radius_q + BZ.Origin_q.Distance; ...
    QZ.Radius_q + QZ.Origin_q.Distance;  ]);
phiL_rad = S.Speaker_Arc_Angle / 180 * pi;
f_cutoff = SigInfo.c * (S.Loudspeaker_Count - 1) / (2 * R_ * phiL_rad);
f_cutoff = mean(f_cutoff .* [1, 2]);

% Match two signals
% Adjust second masker to suit first
[newsig, adjVal] = Broadband_Tools.power_norm( Rec_Q{2}.Rec_Sigs_Q', Rec_Q{3}.Rec_Sigs_Q', SigInfo.Fs, f_cutoff );
Rec_Q{3}.Rec_Sigs_Q = newsig';
Rec_B{3}.Rec_Sigs_B = Rec_B{3}.Rec_Sigs_B * adjVal; % Same adjustment to bright second masker

end

