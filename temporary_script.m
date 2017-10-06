
 clear; 

%%
% fs = 16000;
% dbPerOct = 3.0; %dB
% f_band = [100 2000];
%
%
% Noct = 2;
% offsetdB = 0.377*Noct;
%
%
% fmid = 10^mean(log10(f_band));
% f_edges = [1 f_band(1) fmid f_band(2) fs/2];
%
% f_intpts = (f_band'*2.^(Noct/2*[-1 0 1]))';
%
% a = db2mag( ...
%     dbPerOct/log10(2) * log10(f_edges/fmid) );
% a([1 end]) = a([2 end-1]);
%
% a_ = db2mag( ...
%     dbPerOct/log10(2) * log10(f_intpts/fmid) );
% a_([1 end]) = a_(2,:);
%
%
% a_(f_intpts == f_band) = db2mag(mag2db(a_(f_intpts == f_band)) + [1 -1]'*offsetdB);
%
% f_i_rnd = round(f_intpts);
% a_before = a(1)*ones(1,numel(f_edges(1):f_i_rnd(1,1)));
% a_int = a_before;
% for cf = 1:numel(f_band)
%     interpFrqs = f_i_rnd(1,cf)+1:f_i_rnd(end,cf);
%
%     a_interp = db2mag( ...
%         lagrangepoly( ...
%         log10(f_intpts(:,cf)), ...
%         mag2db(a_(:,cf)), ...
%         log10(interpFrqs))  );
%
%     if cf < numel(f_band)
%         a_after = db2mag( ...
%             dbPerOct/log10(2) * log10( ...
%             (f_i_rnd(end,cf)+1:f_i_rnd(1,cf+1)) /fmid) );
%     elseif f_i_rnd(end,cf) < f_edges(end)
%         a_after = a(end)*ones(1,numel(f_i_rnd(end,end)+1:f_edges(end)));
%     else
%         a_after=[];
%     end
%
%     a_int = [a_int a_interp a_after];
% end
%
% f = f_edges(1):f_edges(end);
%
% plot(f_edges/1e3,mag2db(a)); hold on;
% plot(f/1e3,mag2db(a_int)); hold on;
% grid on; grid minor;
% set(gca,'xscale','log');
% xlim([0.01 10]); hold off;

%%
fs = 16000;
f_band = [100 2000];
fmid = 10^mean(log10(f_band));
res = 100;
F = (0:res:fs/2)/(fs/2);
A = ((0:res:fs/2));
H = A .* exp(1j*pi/2);
f = fdesign.arbmagnphase('Nb,Na,F,H',4,1,F,H);
W = [ 0*ones(1,numel(0:res:f_band(1)-1)) ...
    10*ones(1,numel(f_band(1):res:f_band(2) )) ...
    0*ones(1,numel(f_band(2)+1:res:fs/2)) ];
Hd = design(f,'iirls','Weights',W);

if isstable(Hd), HdSt='true';else,HdSt='false';end
fprintf('WFS/SDM IIR(LS) pre-filter is stable: %s\n',HdSt);
fprintf('WFS/SDM IIR(LS) pre-filter length: %d\n',Hd.impzlength);

imp = Hd.impulse;
imp = imp.Data;

% fvtool(Hd,'polezero')
% fvtool(Hd,'impulse')

% hfvt = fvtool(Hd,'Analysis','freq', 'Fs',16000, 'PhaseUnits','Degrees','Color','w');
% ax = findall(hfvt.Children,'Type','Axes');
% ax.XScale = 'log';

%%
% [num,den]=iirlpnorm(8,8,f/(fs/2),f/(fs/2),a_int);
% [num,den]=iirlpnorm(8,8,f/(fs/2),f/(fs/2),f/(fs/2));
%
% fvtool(num,den);


%%
 % clc;
% close all;


c = 343;                    % Sound velocity (m/s)
fs = 16000;                 % Sample frequency (samples/s)
L = [3 3 3];                % Room dimensions [x y z] (m)
n = 0.1*fs;                 % Number of samples
mtype = 'omnidirectional';  % Type of microphone
mtypeW= 'cardioid';         % Type of microphone
order = 2;                  % -1 equals maximum reflection order
dim = 3;                    % Room dimension
orientation = 0;            % Microphone orientation (rad)
hp_filter = 0;              % Enable high-pass filter
rng shuffle;

%%%
betaW     = (1 - [1.0   [1 1 1 1 1]*1.0]).^2;                 % Reverberation time (s)
%%%
beta(1,:) = (1 - [1.0   [1 1 1 1 1]*1.0]).^2;                 % Reverberation time (s)

beta(2,:) = (1 - [1.0   [0 1 1 1 1]*1.0]).^2;                 % Reverberation time (s)
beta(3,:) = (1 - [1.0   [1 0 1 1 1]*1.0]).^2;                 % Reverberation time (s)
beta(4,:) = (1 - [1.0   [1 1 0 1 1]*1.0]).^2;                 % Reverberation time (s)
beta(5,:) = (1 - [1.0   [1 1 1 0 1]*1.0]).^2;                 % Reverberation time (s)
beta(6,:) = (1 - [1.0   [1 1 1 1 0]*1.0]).^2;                 % Reverberation time (s)
%%%

rtxN = 61;
[yy,zz] = meshgrid(linspace(0,3,rtxN)); % Planar Array
% yy = linspace(0,3,rtxN); zz = yy*0+1.5; % Linear Array

%%% taper window to limit diffraction
winPerc = 20;
[Wx,Wy] = meshgrid( tukeywin(rtxN,winPerc/100) );
DiffracWin = Wx .* Wy;
%%%

rtx = [zeros(numel(yy),1), yy(:), zz(:)];
srx = rtx;

imgSingle = 3;
res = 20;
[XX,YY] = meshgrid(linspace(0,3,3*res));


MC=[];MF=[];M=[];MI=[];PP=[];
hh1=zeros((3*res)^2,n);
hh2=hh1;
tic;
ss=0;
% while ss < numel(XX) %ss<1 %for ss = 1:10
%     ss = ss+1;

img = imgSingle;
[b,a] = cheby1(6,0.1,[250 1500]/(fs/2));

s  = [1.5 2.5 1.5];    % Source position [x y z] (m)

%%% Mic transfer functions
stx = s;              % Source position [x y z] (m)
htx = rir_generator(c, fs, rtx, stx, L, [0 beta(img,2:end)], n, mtypeW, order-1, dim, orientation, hp_filter);
htxLR = htx - ... % Last reflection
    rir_generator(c, fs, rtx, stx, L, [0 beta(img,2:end)], n, mtypeW, order-2, dim, orientation, hp_filter) ;
%%%

current_pool = gcp; %Start new pool
fprintf('\n====== Building RIR Database ======\n');
fprintf('\t Completion: '); startTime = tic;
Tools.showTimeToCompletion;
percCompl = parfor_progress( (3*res)^2 );
parfor ss = 1:(3*res)^2
    [x_,y_] = ind2sub(size(XX),ss);
    
    x = XX(x_,y_); y = YY(x_,y_);
    r  = [ x   y  1.5];    % Receiver positions [x_1 y_1 z_1 ; x_2 y_2 z_2] (m)
%     s  = [1.5 2.5 1.5];    % Source position [x y z] (m)
%     r = rand(1,3).*[1.5 3 3] + [1.5 0 0];    % Receiver positions [x_1 y_1 z_1 ; x_2 y_2 z_2] (m)
%     s = rand(1,3).*[1.5 3 3] + [1.5 0 0];    % Receiver positions [x_1 y_1 z_1 ; x_2 y_2 z_2] (m)
    % s = [rand(1,2)*3 1.5]; r = [rand(1,2)*3 1.5]; % When using linear array
    
    for img = imgSingle%1:6
        
        %%% Ground truth reflections
        h1 = rir_generator(c, fs, r, s, L, [1 beta(img,2:end)], n, mtype, order, dim, orientation, hp_filter);
        h2 = rir_generator(c, fs, r, s, L, [0 beta(img,2:end)], n, mtype, order, dim, orientation, hp_filter);
        h1_ = h1-h2;
        hf = h1_(:);
        %%%

        %%% Loudspeaker transfer functions
        rrx = r;    % Receiver positions [x_1 y_1 z_1 ; x_2 y_2 z_2] (m)
        hrx=[]; hrxLR=[];
        for i = 1:size(rtx,1)
            hrx(i,:) = rir_generator(c, fs, rrx, srx(i,:), L, beta(img,:), n, mtype, order-1, dim, orientation, hp_filter);
            hrxLR(i,:) = rir_generator(c, fs, rrx, srx(i,:), L, beta(img,:), n, mtype, order-2, dim, orientation, hp_filter);
        end
        
        %%% Determine carioid pattern multiplier
        th = atan( ...
            sqrt( (srx(:,2) - rrx(2)).^2 + (srx(:,3) - rrx(3)).^2 ) ...
            ./ (srx(:,1) - rrx(1)) );
        alph = 0.5; % cardioid
        A = alph + (1-alph)*cos(th.');      
        %%%
        
        %%% Apply WFS/SDM pre-filter
        hrx = Tools.fconv(hrx.',repmat(imp.',size(hrx,1),1).').';
        hrxLR = Tools.fconv(hrxLR.',repmat(imp.',size(hrxLR,1),1).').';
        %%%
        
        %%% Cancellation signal minus last refelction
        hc = Tools.fconv(htx.' .* A  ,hrx.');        
        hcLRdirect = Tools.fconv(htxLR.' .* A  ,hrxLR.');
        hcLR = Tools.fconv(htxLR.' .* A  ,hrx.');
        hcL = (hcLR - hcLRdirect);
        
%         hc = hc .* repmat(DiffracWin(:).',size(hc,1),1);
        hc = sum(hc(1:numel(hf),:),2) / rtxN^2 / pi;
%         hcL = hcL .* repmat(DiffracWin(:).',size(hcL,1),1);
        hcL = sum(hcL(1:numel(hf),:),2) / rtxN^2 / pi;
        
        
        hc = hc - hcL;
        %%% 
        
        
        % hI_band = filter(b,a,hI);
        hf_band = filter(b,a,hf);
        hc_band = filter(b,a,hc);
%         figure(1);
%         % plot(hI_band); hold on
%         plot(hf_band); hold on
%         plot(hc_band); hold on;
%         % plot(hf_band - hc_band); hold on;
%         hold off
hh1(ss,:) = hf_band;
hh2(ss,:) = hc_band;
        
%         h = hf-hc;
%         
%         HF = fft(hf);
%         HC = fft(hc);
%         H = fft(h);
% %         HI = fft(hI);
%         
%         ff = linspace(0,fs/2,n/2+1)/1e3;ff(end)=[];
%         
%         MagnitudeC = abs(HC);
%         MagnitudeC(end/2+1:end)=[];
%         MagnitudeF = abs(HF);
%         MagnitudeF(end/2+1:end)=[];
%         Magnitude = abs(H);
%         Magnitude(end/2+1:end)=[];
%         
%         PhaseDifference = mod(unwrap(angle(HF)) - unwrap(angle(HC)) + pi,2*pi)/pi*180-180;
%         PhaseDifference(end/2+1:end)=[];
%         
%         MC(:,ss,img) = MagnitudeC;
%         MF(:,ss,img) = MagnitudeF;
%         M(:,ss,img) = Magnitude;
%         PP(:,ss,img) = PhaseDifference;
%         % MM = mean([MM , MagnitudeC.*ff.' ],2);
%         % PP = mean([PP , PhaseDifference  ],2);
        
    end
    % figure(2);
    % subplot(2,1,1);
    % plot(ff, mag2db(  MC  ),':k'); hold on;
    % plot(ff, mag2db(  mean(MC,2)  ),'-b','linew',1.5); hold on;
    % plot(ff, mag2db(  MF  ),':m'); hold on;
    % plot(ff, mag2db(  mean(MF,2)  ),'-g','linew',1.5); hold off;
    % xlim([0.1 10]); %ylim([-60 0]);
    % grid on; grid minor; set(gca,'xscale','log');
    % xlabel('Frequency (kHz)');ylabel('Magnitude (dB)');
    %
    % subplot(2,1,2);
    % plot(ff, PP ,':k'); hold on;
    % plot(ff, mean(PP,2) ,'-','co',.8*[1 0 0],'linew',1.5); hold off;
    % xlim([0.1 10]); ylim([-180 180]); yticks([-180:45:180]);
    % grid on; grid minor; set(gca,'xscale','log');
    % xlabel('Frequency (kHz)');ylabel('Phase (\circ)');
    
%     figure(2);
%     meanMF = mag2db(mean(MF,2));
%     % plot(ff, mag2db(  MF        ) - meanMF  ,':k'); hold on;
%     % plot(ff, mag2db(  M         ) - meanMF  ,':m'); hold on;
%     plot(ff, mag2db(  mean(MF(:,:,1),2) ) - meanMF(:,:,1)  ,'-k','linew',1.5); hold on;
%     set(gca,'ColorOrderIndex',1);
%     for img = 3%1:6
%         plot(ff, mag2db(  mean( M(:,:,img),2) ) - meanMF(:,:,img)  ,'-','linew',1.5); hold on;
%     end
%     hold off;
%     xlim([0.1 10]); ylim([-30 20]);
%     grid on; grid minor; set(gca,'xscale','log');
%     xlabel('Frequency (kHz)');ylabel('Magnitude (dB)');
%     legend({'Active Wall Off'; ...
%         'Active Wall On & 1 Reflection'; ...
%         'Active Wall On & 2 Reflections'; ...
%         'Active Wall On & 3 Reflections'; ...
%         'Active Wall On & 4 Reflections'; ...
%         'Active Wall On & 5 Reflections'; ...
%         'Active Wall On & 6 Reflections'}, ...
%         'Location','northwest');
%     

% figure(111); scatter(x,y,'ok'); hold on;
% xlim([0 3]); ylim([0 3]);

% drawnow;

        %%%
        percCompl = parfor_progress;
        Tools.showTimeToCompletion( percCompl/100, [], [], startTime );
        %%%

end
percCompl=parfor_progress(0);
tEnd = toc;
fprintf('\nRIR execution time: %dmin(s) %fsec(s)\n\n', floor(tEnd/60), rem(tEnd,60)); %Time taken to execute this script

%%
hh(:,:,:,1) = reshape(hh1,3*res,3*res,[]);
hh(:,:,:,2) = reshape(hh2,3*res,3*res,[]);

[~,IC] = max(abs(hh(ceil(size(XX,1)/2),ceil(size(XX,2)/2),:,1))); % spatial-centre time-index
FIELDERROR = diff(hh(:,:,IC,:),[],4);
imagesc(FIELDERROR);

%%
v = VideoWriter('IRcancelwall.avi','Uncompressed AVI');
open(v);
hhRender = hh(:,2:end,:,:);
maxV = max( abs( hhRender(:) ) ) * 0.5;
C = repmat(linspace(0,1,256)',1,3);
for i = 1:600
FIELDERROR = hh(:,:,i,1);
image((FIELDERROR / maxV /1 + 1 ) * size(C,1)/2);
set(gcf,'Position',[100 100 500 500])
disp(i);colormap(C); axis equal; drawnow;
set(gcf,'Renderer','zbuffer');
writeVideo(v,getframe);
end
for i = 1:600
FIELDERROR = hh(:,:,i,2);
image((FIELDERROR / maxV /1 + 1 ) * size(C,1)/2);
set(gcf,'Position',[100 100 500 500])
disp(i);colormap(C); axis equal; drawnow;
set(gcf,'Renderer','zbuffer');
writeVideo(v,getframe);
end
for i = 1:600
FIELDERROR = diff(hh(:,:,i,:),[],4);
image((FIELDERROR / maxV /1 + 1 ) * size(C,1)/2);
set(gcf,'Position',[100 100 500 500])
disp(i);colormap(C); axis equal; drawnow;
set(gcf,'Renderer','zbuffer');
writeVideo(v,getframe);
end
close(v);