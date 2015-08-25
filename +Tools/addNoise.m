function [x_n] = addNoise( x, level, type )
%ADDNOISE Summary of this function goes here
% 
% Syntax:	[OUTPUTARGS] = ADDNOISE(INPUTARGS) Explain usage here
% 
% Inputs: 
% 	x - The input signal to add noise to
% 	level - The noise in dB relative to the input signal
% 	type - The type of noise to add
% 
% Outputs: 
% 	x_n - The noisey output signal
% 
%

% Author: Jacob Donley
% University of Wollongong
% Email: jrd089@uowmail.edu.au
% Copyright: Jacob Donley 2015
% Date: 21 August 2015 
% Revision: 0.1
% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 3
    type = 'UWGN'; % Uniform White Gaussian Noise
end

% Maximum value in input signal
max_val =  max( abs( x(:) ) );

% Level in magnitude
level_mag = db2mag(level);


if strcmp(type,'UWGN')
   
    noise_ = rand( size(x) ) * 2 - 1; % UWGN: -1 to 1
    x_n = x + max_val * noise_ * level_mag;
    
else
    error('''type'' argument for noise not supported');
end

end