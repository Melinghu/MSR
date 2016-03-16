function splitSaveRecording( Recordings, Segment_details, Main_Setup, Room_Setup, signal_info, masker_signal_info, system_info )
%SPLITSAVERECORDING Summary of this function goes here
%   Detailed explanation goes here


%% Get save path
RecPath = Hardware_Control.getRealRecordingsPath( ...
    Main_Setup, ...
    system_info.LUT_resolution, ...
    Room_Setup, ...
    masker_signal_info, ...
    system_info.Drive);

%% Get original audio's file path
[~,~,~,~,~,~,path_ext] = ...
    Broadband_Tools.getLoudspeakerSignalPath( Main_Setup, signal_info, system_info.LUT_resolution, system_info.Drive);
spkr_calib_dir = [system_info.Drive system_info.Calibrated_Signals_dir path_ext];

%% Split and save recordings
seg_lengths = [0, Segment_details.length];
F = length(Segment_details);
for f = 1:F
    
    seg_start = sum(seg_lengths(1:f))+1;
    seg = seg_start : (seg_start-1 + seg_lengths(f+1));
    
    Rec_Sigs_B = Recordings( seg, 1:ceil(end/2) ); %Assumes odd number of recordings has one more recording in bright zone
    Rec_Sigs_Q = Recordings( seg, ceil(end/2)+1:end );
    fs = system_info.fs;
    
    if ~exist( RecPath, 'dir'); mkdir(RecPath); end
    
    save( ...
        [RecPath, Segment_details(f).filename, system_info.sc, 'Bright.mat'], ...
        'Rec_Sigs_B', ...
        'fs' );
    save( ...
        [RecPath, Segment_details(f).filename, system_info.sc, 'Quiet.mat'], ...
        'Rec_Sigs_Q', ...
        'fs' );
    
    [orig,fs]=audioread( ...
        [spkr_calib_dir, ...
        Segment_details(f).filename, system_info.sc, ...
        'Original', Segment_details(f).fileext]);
    audiowrite( ...
        [RecPath, ...
        Segment_details(f).filename, system_info.sc, ...
        'Original', Segment_details(f).fileext] , ...
        orig, fs);
    
end

end

