classdef spatial_zone
    % SPATIAL_ZONE - This class represents a spatial audio zone for
    %                multizone soundfield reproduction.
    %
    %   This class was implemented based on the publication:
    %   Y. J. Wu and T. D. Abhayapala, "Spatial multizone soundfield
    %   reproduction: Theory and design," Audio, Speech, and Language
    %   Processing, IEEE Transactions on, vol. 19, pp. 1711-1720, 2011.
    %
    %   Author: Jacob Donley, University of Wollongong, Australia
    %   Email: Jacob.Donley089@uowmail.edu.au
    %
    
    properties
        res = 50;                                           % Samples per metre %Resolution of soundfield should be inherited
        Radius_q = 0.5;                                     % Radius of the zone in metres
        Origin_q = struct('X',0,'Y',0);                     % Coordinates from the global origin
        Weight = 1.0;                                       % Output amplitude from 0.0 (no output) to 1.0 (max output)
        Frequency = 1000;                                   % Frequency of source
        Phase = 0*pi;                                       % Phase of source
        SourceType = 'pw';                                  % 'pw' = Plane Wave, 'ps' = Point Source, 'quiet' = Quiet Zone
        SourceOrigin = struct('Distance', 1.0, 'Angle', 0); % This location is relative to the origin of this particular zone
        Soundfield_d_mask;                                  % Circular soundfield mask for a square array
        Soundfield_d = [];                                  % The complex values of the desired sound field made from spherical harmonics.
        Sd = [];                                            % Ideal desired soundfield
        Alpha_Coeffs = [];                                  % Alpha_Coeffs is a set of coefficients uniquely representing the qth desired soundfield
    end
    
    
        
    methods (Access = private)
            
        function obj = createEmptySoundfield_d(obj)
            width = int16(obj.res * obj.Radius_q * 2);
            xyvec = linspace(-obj.Radius_q, obj.Radius_q, width);
            [xx,yy] = meshgrid(xyvec,xyvec);
            obj.Soundfield_d_mask = xx.^2 + yy.^2 <= (obj.Radius_q)^2 * ones(width, width);
            obj.Soundfield_d = zeros(width,width);
        end
        
    end
    
    
    
    methods
        function obj = spatial_zone(frequency, phase, radius, type, weight, angle, distance)
            if nargin < 7;	distance = obj.SourceOrigin.Distance;
            if nargin < 6;	angle = obj.SourceOrigin.Angle;
            if nargin < 5;	weight = obj.Weight;
            if nargin < 4;	type = obj.SourceType;
            if nargin < 3;	radius = obj.Radius_q; 
            if nargin < 2;	phase = obj.Phase; end; end; end; end; end; end;
           % Save values to the object
           obj.Frequency = frequency;
           obj.Phase = phase;
           obj.Radius_q = radius;
           obj.SourceType = type;
           obj.Weight = weight;
           obj.SourceOrigin.Angle = angle;
           obj.SourceOrigin.Distance = distance;
           %obj = obj.setDesiredSoundfield(frequency, radius, type, weight, angle, distance);
        end
        
        function obj = setOrigin(obj, X_Coord, Y_Coord)
            obj.Origin_q.X = X_Coord;
            obj.Origin_q.Y = Y_Coord;
        end
        
        function [r_0q, theta_0q] = getOriginInPolarCoords(obj)
            [theta_0q, r_0q] = cart2pol(obj.Origin_q.X,obj.Origin_q.Y);
        end
        
        function k = getWavenumber(obj)
            k = obj.Frequency / 343 * (2 * pi);
        end
        
        function obj = createEmptySoundfield(obj)
           obj = obj.createEmptySoundfield_d;
        end        
        
        function obj = setDesiredSoundfield(obj, ideal, frequency, phase, radius, type, weight, angle, distance)
            if nargin < 9;  distance = obj.SourceOrigin.Distance;
            if nargin < 8;     angle = obj.SourceOrigin.Angle;
            if nargin < 7;    weight = obj.Weight;
            if nargin < 6;      type = obj.SourceType;
            if nargin < 5;    radius = obj.Radius_q;
            if nargin < 4;     phase = obj.Phase;
            if nargin < 3; frequency = obj.Frequency;                 
            if nargin < 2;     ideal = false; 
            end;end;end;end;end;end;end;end;
      
           suppress_output = false;
           if strcmp(frequency, 'suppress_output') 
                frequency = obj.Frequency;
                suppress_output = true;
           end
           % Save values to the object
           obj.Frequency = frequency;
           obj.Phase = phase;
           obj.Radius_q = radius;
           obj.SourceType = type;
           obj.Weight = weight;
           obj.SourceOrigin.Angle = angle;
           obj.SourceOrigin.Distance = distance;
           
           k = frequency / 343 * (2 * pi);
           if ~suppress_output
            fprintf('Monofrequent Spatial Zone:\n');
            fprintf('\tFrequency: %0.0f Hz\n', frequency );
            fprintf('\tWavenumber: %0.2f m��\n', k);
            fprintf('\tPhase: %0.1f �\n', phase/pi*180);
            fprintf('\tAngle: %0.1f �\n\n', angle);
           end
           R_src = distance;
           Phi_src = angle / 180 * pi; %convert to radians
           obj = obj.createEmptySoundfield_d;
           O_q_z = length(obj.Soundfield_d) / 2; %Set the centre of the zone for indexing
           
            
            if ~ideal 
% START %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
           % Cylindrical Harmonic Expansion
           
           Mq = ceil( k * exp(1) * obj.Radius_q / 2); % Set the maximum mode           
           % Find Alpha coefficients for the desired soundfield in the zone
           obj.Alpha_Coeffs = [];
           for m = -Mq:Mq
            if (strcmp(type, 'pw'))
            	alpha = 1j^m * exp( -1j * m * Phi_src);                 % From reference [17], equation (8)                
            elseif (strcmp(type, 'ps'))
                alpha = besselh(m, k * R_src) * exp(-1j * m * Phi_src); % From reference [17], equation (11)
            elseif (strcmp(type, 'noise'))
                alpha = 1.0;
            elseif (strcmp(type, 'quiet'))
                alpha = 0;
            end
            alpha = alpha * weight;
            obj.Alpha_Coeffs = [obj.Alpha_Coeffs alpha];
           end
           
           % TODO: Instead of using a for loop for the cartesian x and y
           % coords use a for loop for all radii and one revolution
           for x = 1:length(obj.Soundfield_d)
            for y = 1:length(obj.Soundfield_d)                
                [OMEGA_q, R_q] = cart2pol(x - O_q_z, y - O_q_z); %Convert to polar coords from centre of the zone
                R_q = R_q / obj.res;  %Change to spatial radius (/metre)
                for m = -Mq:Mq                    
                    J = besselj(m, k * R_q );
                    e = exp(1j * m * OMEGA_q);
                    obj.Soundfield_d(y, x) = obj.Soundfield_d(y, x) + obj.Alpha_Coeffs(m+Mq+1) * J * e; % Sum pressures
                end
            end
           end                       
           
% END %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            elseif ideal
                    % Using Planewave formula
                  width=length(obj.Soundfield_d);
                  x = ((1:width) - width/2) / obj.res;
                  y = x;
                  [xx,yy] = meshgrid(x,y);
                  X = complex(xx,yy);    
                  if strcmp(type, 'quiet')
                      weight = 0;
                  end
                  obj.Soundfield_d = weight .* exp( 1i * (k * (cos(Phi_src)*real(X) + sin(Phi_src)*imag(X)) + phase) ); %Planewave formula ( e^(i*(kx+ky+kz)) )
                  if (strcmp(type, 'noise'))
                      obj.Soundfield_d = ones(size(X));
                  end
            else
                return;
            end
        end       
        
        function plotSoundfield(obj)
            ZaxisSize = max(abs(real(obj.Soundfield_d(:))));
            figure;
            
            subplot(1,2,1);
            surf(real(obj.Soundfield_d) .* obj.Soundfield_d_mask,'EdgeColor','None');
            view(2);
            title('Real');
            axis('square');
            axis([1 length(obj.Soundfield_d) 1 length(obj.Soundfield_d)]);
            caxis([-ZaxisSize ZaxisSize]);
            colormap gray; 
            
            subplot(1,2,2);
            surf(imag(obj.Soundfield_d) .* obj.Soundfield_d_mask,'EdgeColor','None');
            view(2);
            title('Imag');
            axis('square');
            axis([1 length(obj.Soundfield_d) 1 length(obj.Soundfield_d)]);
            caxis([-ZaxisSize ZaxisSize]);
            colormap gray; 
            
%             subplot(2,2,3);
%             surf(real(obj.Soundfield_d) .* obj.Soundfield_d_mask);
%             title('Real');
%             axis('square');
%             subplot(2,2,4);
%             surf(imag(obj.Soundfield_d) .* obj.Soundfield_d_mask);
%             title('Imag');
%             axis('square');
        end
    end

    
end
