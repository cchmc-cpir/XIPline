function [GasExResults, CalResults] = GE_calibration(MainInput)
%RECON_CALIBRATION Reconstruct 129Xe calibration
% [bb,bbabs] = recon_calibration(d,h,wfn,mtx,delay,lb,fname,comb_time)
%                                                               (default)
%         d  Raw (p-file) data  (or pfile fname)
%         h  Header from p-file (or empty)
%   wfnpath  Location of waveform .mat file
%     delay  Gradient-acquisition delay                   [pts] (0)
%     fname  Print <fname>.png and save reco as <fname>.mat     ([]) 
%            also export dicom if template.dcm is found
%
%        bb  Reconstructed data       (mtx,mtx,mtx,#timesteps,#coils)
%     bbabs  RMS coil-combined data   (mtx,mtx,mtx,#timesteps)
%
% 12/2020 Rolf Schulte
if (nargin<1), help(mfilename); return; end

dCal = MainInput.CalFullPath;
fname = dCal;
h = [];
[fp,fn] = fileparts(MainInput.CalFullPath);
cd(fp);
%% input variables
if ~exist('delay','var'), delay = []; end
if isempty(delay),      delay = 0; end
if length(delay)~=1, error('length(delay)(=%g)~=1',length(delay)); end
if ~exist('fname','var'), fname = []; end
if ~isempty(fname)
    if ~islogical(fname)
        if ~isempty(regexpi(fname,'\.7$')), fname = fname(1:end-2); end
        if ~isempty(regexpi(fname,'\.h5$')), fname = fname(1:end-3); end
        if ~isempty(regexpi(fname,'\.mat$')), fname = fname(1:end-4); end
    end
end

filepath = dCal;
%% reading in data, if pfile name is given
if ~isnumeric(dCal)
    if exist(dCal,'file')
        [d,h] = LoadData.ismrmrd.GE.Functions.read_p(dCal);
    else
        warning('strange input d/file not existing');
    end
end




%% reading waveform file: reading frequencies and flip angles
% The path here should be the path to the local calibration waveform file
wfnpath = 'C:\XIPline\GE\waveforms\xe_calibration';
% Define file patterns to search for
% filePatterns = {'*freq.fdl', '*TR.fdl'};
filePatterns = {'*.mat', '*freq.fdl', '*flip.fdl'};
filePaths = {};
for i = 1:length(filePatterns)
    fileList = dir(fullfile(wfnpath, filePatterns{i}));
    if isempty(fileList)
        fprintf('No file matching %s found in the directory.\n', filePatterns{i});
    else
        % Append each matching file's full path to the list
        for j = 1:length(fileList)
            filePaths{end+1} = fullfile(wfnpath, fileList(j).name);
        end
    end
end

wfn = filePaths{1};
if isempty(wfn), error('wfn empty'); end
if isstruct(wfn)
    wf = wfn;
else
    if ~isempty(regexpi(wfn,'\.wav$')), wfn = wfn(1:end-4); end
    if isempty(regexpi(wfn,'\.mat$')),  wfn = [wfn '.mat']; end
    if ~exist(wfn,'file'), error('file not found: wfn=%s',wfn); end
    wf = load(wfn);          % load waveform
end

% Display the full paths
if isempty(filePaths)
    disp('No matching files found.');
else
    fprintf('Matching files found:\n');
    disp(filePaths');
end
fdl_freq_file = filePaths{2};
freq_array = LoadData.ismrmrd.GE.Functions.read_fdl(fdl_freq_file);

fdl_tr_file = filePaths{3};
flip_array = LoadData.ismrmrd.GE.Functions.read_fdl(fdl_tr_file);

% freq_array = read_fdl([wfn(1:end-4) '_freq.fdl']);
% flip_array = read_fdl([wfn(1:end-4) '_flip.fdl']);

%% check fields required for reconstruction
fina = {'ts','n_ind'};
for l=1:length(fina)
    if ~isfield(wf,fina{l}), error('wf.%s not existing',fina{l}); end
end

%% Separate spectra
% cali_struct = LoadData.ismrmrd.GE.Functions.readRawCali(filepath);
% xeFreqMHz = cali_struct.xeFreqMHz;

skipped_frames_diss = 50;                        % Number of spectra to ignore for downstream saturation
skipped_frames_gas = 20;
%bw = h.rdb_hdr.user0;                       % full acq bandwidth [Hz]
%[nexc,~,nphases,nechoes,nslices,ncoils] = size(d); % data size

dps = freq_array ~= 0;
kdata_dissolved = d(dps==1,2:end);
dps(1:skipped_frames_diss) = 0;
gps = freq_array == 0;

skipped_frames_gas = min(skipped_frames_gas,ceil(sum(gps)/3));
skipped_frames_gas = 0;
data_dissolved = d(dps == 1,2:end);     % Toss first point
data_gas = d(gps(1:size(d,1)) == 1,2:end);  % Toss first point
data_gas(1:skipped_frames_gas,:) = []; 
end_frame = min(size(data_gas,1),80);
data_gas = data_gas(1:end_frame,:);


if mean(angle(mean(data_dissolved(1:2:end,:)./data_dissolved(2:2:end,:)))) < -3
    data_dissolved(2:2:end,:) = data_dissolved(2:2:end,:).*exp(1i*pi);
    data_gas(2:2:end,:) = data_gas(2:2:end,:).*exp(1i*pi);
elseif mean(angle(mean(data_dissolved(1:2:end,:)./data_dissolved(2:2:end,:)))) > 3
    data_dissolved(2:2:end,:) = data_dissolved(2:2:end,:).*exp(-1i*pi);
    data_gas(2:2:end,:) = data_gas(2:2:end,:).*exp(-1i*pi);
end

data_avg = mean(data_dissolved);

%% Do the spectral fitting
gas_idx = 1;
barrier_idx = 2;
rbc_idx = 3;

area_orig = [.1 1 1];
freq_orig = [max(abs(freq_array)) 800 -100];
fwhm_orig = [1 250 250];
fwhmG_guess = [0, 0, 0] ;
phase_orig = pi*randn(1,3);
noise_est = max(abs(data_avg(end,end-10:end)));
disfitObj = Calibration.NMR_TimeFit_v(data_avg, wf.ts(2:end), area_orig,freq_orig,fwhm_orig,fwhmG_guess, phase_orig,[],[]);
disfitObj.fitTimeDomainSignal();
% [area_f, freq_f, fwhm_f, phase_f] = calcTimeDomainSignalFit(disfitObj);
% disfitObj.area = area_f;
% disfitObj.freq = freq_f;
% disfitObj.fwhm = fwhm_f;
% disfitObj.phase = phase_f;
disp('            Area     Freq (Hz)   Linewidths(Hz)   Phase(degrees)');
peakName = {'     RBC:', 'Membrane:', '     Gas:'};
for iComp = 1:length(disfitObj.area)
    disp([peakName{iComp}, '  ', ...
        sprintf('%8.3e', disfitObj.area(iComp)), ' ', ...
        sprintf('%+8.2f', disfitObj.freq(iComp)), '  ', ...
        sprintf('%8.2f', abs(disfitObj.fwhm(iComp))), '  ', ...
        sprintf('%8.2f', abs(disfitObj.fwhmG(iComp))), '  ', ...
        sprintf('%+9.2f', disfitObj.phase(iComp))]);
end

if disfitObj.freq(rbc_idx) > 0
    rbc_idx = 2;
    barrier_idx = 3;
end
area_f = disfitObj.area;
freq_f = disfitObj.freq;
fwhm_f = disfitObj.fwhm;
phase_f = disfitObj.phase;

%% RBC:Barrier Ratio
meanRbc2barrier = disfitObj.area(rbc_idx)/disfitObj.area(barrier_idx);
% meanRbc2barrier = disfitObj.area(2)/disfitObj.area(3);

%% Compute TE90
te = h.rdb_hdr.te*1e-6;

deltaF = disfitObj.freq(barrier_idx)-disfitObj.freq(rbc_idx);
deltaPhase = disfitObj.phase(barrier_idx)-disfitObj.phase(rbc_idx);
time180 = abs(1/(2*deltaF));
te90 = (90-deltaPhase*(1+360/deltaPhase*(deltaPhase < -90)))/(360*deltaF);

% deltaPhase = disfitObj.phase(2) - disfitObj.phase(1); % RBC-Membrane phase diff in cal spectrum
% deltaPhase = mod(abs(deltaPhase), 180); % deal with wrap around, but also negative phase
% deltaF = abs(disfitObj.freq(2)-disfitObj.freq(1)); % absolute RBC-membrane freq difference
% time180 = abs(1/(2*deltaF));
% deltaTe90 = (90 - deltaPhase) / (360 * deltaF); % how far off are we?
% te90 = (te + deltaTe90 * 1e6)/1000; % in usec

while(te90<0)
    % This TE is too low, so add 180 deg of phase
    te90 = te90 + time180;
end
while(te90>time180)
     % This te is too high, so subtract 180 deg of phase
    te90 = te90 - time180;
end

% make te90 a multiple of 4us + 2us
te90 = ceil(te90*1e6);
if mod(te90,4)
    te90 = te90 + 4 - mod(te90,4);
end
te90 = (te90 + 2)*1e-6;

te90 = te90 + te + 20e-6;   % Account for skipping first point
%% Estimate flip angle

% Compute the gas peak area for each specta
area_orig = 1000;
freq_orig = 0;
fwhm_orig = 1;
phase_orig = 0;

Ng = size(data_gas,1);
area_g = zeros(1,Ng);
freq_g = zeros(1,5);

% for s = 1:5
%     gasFit = Calibration.NMR_Fit(data_gas(s,:), wf.ts(2:end), area_orig,freq_orig,fwhm_orig,phase_orig,[],[]);
%     [~,freq_g(s),~,~] = calcTimeDomainSignalFit(gasFit);
% end
for s = 1:5
    gasfitObj = Calibration.NMR_TimeFit(data_gas(s,:), wf.ts(2:end), area_orig,freq_orig,fwhm_orig,phase_orig,[],[]);
    gasfitObj.fitTimeDomainSignal();
    gasfitObj.describe();
    freq_g(s) = gasfitObj.freq(1);
end

%% Compute AX
center_freq = h.rdb_hdr.ps_mps_freq/10;
targetAX = round(center_freq - median(freq_g));
area_g(1,:) = abs(data_gas(:,4));

flip_fit = fit((1:Ng)',area_g','exp1');
targetFA = flip_array(end);                     % This is the target we wanted to hit
actualFA = acosd(exp(flip_fit.b));                          % This is the estimate
FlipScaleFactor = actualFA/targetFA;

% Dixon TG - compute the TG that provides the targetFA
targetTG = ceil(h.rdb_hdr.ps_mps_tg + 200*log10(targetFA./actualFA));

%% saving result as mat file
fname = filepath;
[fp,fn] = fileparts(filepath);
if ~isempty(fname)
    save([fn '.mat'],'-mat','-v7.3',...
        'targetTG','targetAX','te90','meanRbc2barrier','data_dissolved','data_gas','data_avg','area_f','freq_f','fwhm_f','phase_f','area_g','fname');
end

%% saving data for external processing
kdata_dissolved = kdata_dissolved.';
tr = h.image.tr*1e-6;
spec_tsp = wf.ts(2);
date = ['20' h.rdb_hdr.scan_date(end-1:end) '-' h.rdb_hdr.scan_date(1:2) '-' h.rdb_hdr.scan_date(4:5)];

[fp,fn] = fileparts(fname);

save([fp '/Spect_' fn '.mat'],'-mat','-v7.3',...
        'kdata_dissolved','tr','center_freq','spec_tsp','date');

%% plotting

figure; set(gcf,'DefaultAxesFontSize',14);
fa_text = sprintf('Target FA = %.1f\nActual FA = %.1f\nTarget TG = %d',targetFA,actualFA,targetTG);
fit_line = flip_fit(1:Ng);
subplot(211),plot(1:Ng,area_g,'b',1:Ng,fit_line,'r'); axis([1, Ng, 0.8*min(area_g), 1.2*max(area_g)]);
text(round(Ng*.65), max(area_g), fa_text);

F = disfitObj.f;
dspec = fftshift(fft(data_avg));             % measured average spectrum
% spec_scale = max(abs(dspec))./max(abs(calcSpectralDomainSignal(disfitObj,F)));   % scaling factor for display
spec_scale = max(abs(dspec))./max(abs(disfitObj.spectralDomainSignal));   % scaling factor for display

ds_text = sprintf('RBC:Barrier = %1.2f\nGas Frequency = %dHz\nTE90=%1.3fms\n',meanRbc2barrier,targetAX,te90*1e3);

% Plot measured and fitted spectra
subplot(212),plot(F,abs(dspec),'.r',F,abs(disfitObj.spectralDomainSignal.*spec_scale),'-b'); 
% hold on
% subplot(212),plot(F,abs(disfitObj.spectralDomainSignal.*spec_scale),'b'); 

title('Magnitude');legend('Measured','Estimated','Location','NorthWest');
text(F(10),max(abs(dspec))*.5,ds_text);

% Save figure to file
figstr = sprintf('P%05d Exam%d Series%d',...
    h.image.rawrunnum,h.exam.ex_no,h.series.se_no);
set(gcf,'name',figstr);
[fp,fn] = fileparts(filepath);
if ~isempty(fp)
    saveas(gca,'Calibration_Analysis.png');
end
close all;
%% 

% calculate flip angle
fitfunct = @(coefs,xdata)coefs(1)*cos(coefs(2)).^(xdata-1) + noise_est;   % cos theta decay
% fitfunct = @(coefs,xdata)coefs(1)*cos(coefs(2)).^(xdata-1)+coefs(3);   % cos theta decay
guess(1)=max(area_g);
guess(2)=targetFA*pi/180;
% guess(3)=0;

xdata = 1:length(area_g);
ydata = area_g;

fitoptions = optimoptions('lsqcurvefit','Display','off');
[fitparams,~,residual,~,~,~,jacobian]  = lsqcurvefit(fitfunct,guess,xdata,ydata,[],[],fitoptions);
ci = nlparci(fitparams,residual,jacobian);  % returns 95% conf intervals on fitparams by default
param_err = fitparams-ci(:,1)';
flip_angle = abs(fitparams(2)*180/pi);
flip_err = param_err(2)*180/pi;
FlipScaleFactor = flip_angle/targetFA;

%% Quantify ammount of off resonance excitation
GasDisRatio = disfitObj.area(3)/sum(disfitObj.area(1:2));
fprintf('\nGasDisRatio = %3.3f \n',GasDisRatio); 

%% Quantify RBC:Barrier ratio
RbcBarRatio = disfitObj.area(1)/disfitObj.area(2);
fprintf('RbcBarRatio = %3.3f\n',RbcBarRatio);
%% Store Results for Additional Analysis
%Results to Pass to Gas Exchange Recon
GasExResults.RbcBarRatio = RbcBarRatio;
GasExResults.GasDisRatio = GasDisRatio;
GasExResults.DisFit = disfitObj;

%Results to Pass to Calibration information
CalResults.flip_angle = actualFA;
CalResults.flip_err = flip_err;
CalResults.FlipScaleFactor = FlipScaleFactor;
CalResults.Pulses = xdata;
CalResults.GasDecay = ydata;
CalResults.DecayFit = fitparams;
CalResults.GasFit = gasfitObj;
CalResults.te90 = te90/1000; %to ms
CalResults.freq_target = targetAX;
CalResults.Reference_Voltage = 0;
CalResults.dwell_time = spec_tsp;  
CalResults.noise_est = noise_est;
CalResults.freq = center_freq; 
CalResults.FlipTarget = targetFA;
CalResults.te = te;  
CalResults.nDis = length(data_avg);
CalResults.nCal = length(area_g);
CalResults.VRefScaleFactor = 0;
CalResults.VRef = 0;

end      % main function recon_calibration.m


