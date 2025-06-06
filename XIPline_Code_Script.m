%This script is intended for debugging, developing, and testing new tools before implementing them in the main interface.

%   Package: https://github.com/aboodbdaiwi/HP129Xe_Analysis_App
%
%   Author: Abdullah S. Bdaiwi
%   Work email: abdullah.bdaiwi@cchmc.org
%   Personal email: abdaiwi89@gmail.com
%   Website: https://www.cincinnatichildrens.org/research/divisions/c/cpir
%
%   Please add updates at the end. Ex: 3/10/24 - ASB: update .... 
%% calibration 
[filename, path] = uigetfile('*.*','Select xenon data file');
XeFullPath = [path,filename];
XeDataLocation = path(1:end-1);
[~,~,xe_ext] = fileparts(XeFullPath);

MainInput.XeFullPath = XeFullPath;
MainInput.XeDataLocation = XeDataLocation;
MainInput.XeFileName = filename;
MainInput.XeDataext = xe_ext;
cd(MainInput.XeDataLocation)

[GasExResults, CalResults] = Calibration.XeCTC_Calibration(MainInput);
[GasExResults, CalResults] = Calibration.XeCTC_Calibration_MRD(MainInput); 
% the rest of the calculations is in the main interface 

%% Image analysis (Load Images)
clc; clear; close all; % start with fresh variables, etc.
MainInput.Institute = '';
MainInput.Scanner = '';
MainInput.ScannerSoftware = '';
MainInput.SequenceType = '';
MainInput.XeDataLocation = '';
MainInput.XeDataType = '';
MainInput.NoProtonImage = '';
MainInput.HDataLocation = '';
MainInput.HDataType = '';
MainInput.AnalysisType = '';
MainInput.SubjectAge = [];
MainInput.RegistrationType = '';

% add patinet info
MainInput.PatientInfo = '';

% 1) choose the type of analysis
MainInput.AnalysisType = 'GasExchange';  % 'Ventilation', 'Diffusion', 'GasExchange'

% 2) Do you have protom images? 
MainInput.NoProtonImage = 0;  % 1: There is no proton images  % 0: There is  proton images   

MainInput.Institute = 'XeCTC';  % 'CCHMC', 'XeCTC', 'Duke',  'London'
MainInput.Scanner = 'Siemens'; % Siemens, Philips, GE
MainInput.ScannerSoftware = '5.9.0'; % '5.3.1', '5.6.1','5.9.0'
MainInput.SequenceType = '3D Radial'; % '2D GRE', '3D Radial'
MainInput.denoiseXe= 'no';
% diary Log.txt
[filename, path] = uigetfile('*.*','Select xenon data file');
XeFullPath = [path,filename];
XeDataLocation = path(1:end-1);
[~,Xe_name,xe_ext] = fileparts(XeFullPath);

MainInput.XeFullPath = XeFullPath;
MainInput.XeDataLocation = XeDataLocation;
MainInput.XeFileName = filename;
MainInput.Xe_name = Xe_name;
MainInput.XeDataext = xe_ext;
cd(MainInput.XeDataLocation)

% select calibration
if strcmp(MainInput.Institute,'XeCTC') && strcmp(MainInput.AnalysisType,'GasExchange') %&& (strcmp(app.MainInput.XeDataext,'.dat') || strcmp(app.MainInput.XeDataext,'.p'))
    [filename, path] = uigetfile('*.*','Select calibration data file');
    CalFullPath = [path,filename];
    CalDataLocation = path(1:end-1);
    [~,Cal_name,Cal_ext] = fileparts(CalFullPath);

    MainInput.CalFullPath = CalFullPath;
    MainInput.CalDataLocation = CalDataLocation;
    MainInput.CalFileName = filename;
    MainInput.Cal_name = Cal_name;    
    MainInput.CalDataext = Cal_ext;
end

% select proton
if MainInput.NoProtonImage == 0
    [filename, path] = uigetfile('*.*','Select proton data file');
    HFullPath = [path,filename];
    HDataLocation = path(1:end-1);
    [~,H_name,H_ext] = fileparts(HFullPath);

    MainInput.HFullPath = HFullPath;
    MainInput.HDataLocation = HDataLocation;
    MainInput.HFileName = filename;
    MainInput.H_name = H_name;    
    MainInput.HDataext = H_ext;
end

[Ventilation, Diffusion, GasExchange, Proton] = LoadData.LoadReadData(MainInput);

if strcmp(MainInput.AnalysisType,'Ventilation') == 1                 
    figure; Global.imslice(Ventilation.Image) 
elseif strcmp(MainInput.AnalysisType,'Diffusion') == 1 
    figure; Global.imslice(Diffusion.Image)
elseif strcmp(MainInput.AnalysisType,'GasExchange') == 1 
    figure; Global.imslice(GasExchange.VentImage)
end
if MainInput.NoProtonImage == 0
    figure; Global.imslice(Proton.Image)
end
% Ventilation.Image = flipdim(Ventilation.Image,3); 
% Ventilation.Image = permute(Ventilation.Image,[3 2 1]); % 
% A = flip(Ventilation.Image,1);
% A = flip(A,2);
% Ventilation.Image = A;
% 
% A = flip(Proton.Image,1);
% A = flip(A,2);
% Proton.Image = A;
% 
% Global.imslice(A)


%% Registration 

% Move from 1st to 3rd dim and flip Z (optional)
% Prot_Test = permute(Ventilation.Image,[3 2 1]); %
% Test3 = flip(Prot_Test,1);
% Ventilation.Image = flipdim(Test3,3);
% figure; imslice(Ventilation.Image)

% Flip Z of Vent and Proton (optional)
% Ventilation.Image = flipdim(Ventilation.Image,3);
% Proton.Image = flipdim(Proton.Image,3); 
% Ventilation.LungMask = flipdim(Ventilation.LungMask,3);

% preform registration 
clc
cd(MainInput.XeDataLocation)
%Proton.Image = P_image; % Use only for interpulation
% 
% diary LogFile_LoadingData
MainInput.SkipRegistration = 0;
MainInput.RegistrationType = 'affine'; % 'translation' | 'rigid' | 'similarity' | 'affine'
% enable this code in case number of slices is different between xe and H
MainInput.SliceSelection = 0;
if MainInput.SliceSelection == 1
    MainInput.Xestart = 1;
    MainInput.Xeend = 13;
    MainInput.Hstart = 1;
    MainInput.Hend = 10;
end

if strcmp(MainInput.AnalysisType, 'Ventilation')
    Xesize = size(Ventilation.Image);
    Hsize = size(Proton.Image);
    sizeRatio = Hsize./Xesize;
elseif strcmp(MainInput.AnalysisType, 'GasExchange')
    Xesize = size(GasExchange.VentImage);
    Hsize = size(Proton.Image);
    sizeRatio = Hsize./Xesize;
end

useRatio = 1;
if useRatio == 1
    MainInput.XeVoxelInfo.PixelSize1 = sizeRatio(1);
    MainInput.XeVoxelInfo.PixelSize2 = sizeRatio(2);
    MainInput.XeVoxelInfo.SliceThickness = sizeRatio(3);
else % manual
    MainInput.XeVoxelInfo.PixelSize1 = 1.13; %Y
    MainInput.XeVoxelInfo.PixelSize2 = 1.13; %X
    MainInput.XeVoxelInfo.SliceThickness = 1;
end

MainInput.ProtonVoxelInfo.PixelSize1 = 1;
MainInput.ProtonVoxelInfo.PixelSize2 = 1;
MainInput.ProtonVoxelInfo.SliceThickness = 1;

[Proton] = Registration.PerformRegistration(Proton,Ventilation,GasExchange,MainInput);
viewing_img = Proton.ProtonRegisteredColored;

S = orthosliceViewer(viewing_img,...      
                               'DisplayRange', [min(viewing_img(:))  max(viewing_img(:))]);

%% Load Mask (.nii or .gz)
% clc
% [filename, path] = uigetfile('*.*','Select proton data file');
% cd(path)
% Mask = LoadData.load_nii(filename);
% A = Mask.img;
% A = permute(A,[1 3 2]); 
% A = double(squeeze(A));
% A = imrotate(A,-90);
% A = flip(A,2);                   
% Mask = A;  
% figure; Global.imslice(Mask) 

%% segmenting 
clc
cd(MainInput.XeDataLocation)

% diary Log.txt
MainInput.SegmentationMethod = 'Threshold'; % 'Threshold' || 'Manual' || 'Auto'
MainInput.SegmentAnatomy = 'Airway'; % 'Airway'; || 'Parenchyma'
MainInput.Imagestosegment = 'Xenon';  % 'Xe & Proton Registered' | 'Xenon' | 'Registered Proton'

MainInput.thresholdlevel = 0.3; % 'threshold' 
MainInput.SE = 1;

MainInput.SegmentManual = 'Freehand'; % 'AppSegmenter' || 'Freehand'
MainInput.SliceOrientation = 'transversal'; % 'coronal' ||'transversal' || 'sagittal' ||'isotropic'
[Proton,Ventilation,Diffusion,GasExchange] = Segmentation.PerformSegmentation(Proton,Ventilation,Diffusion,GasExchange,MainInput);

% create vessle mask
if strcmp(MainInput.AnalysisType,'Ventilation')                
    MainInput.SegmentVessels = 0; % 0 || 1
elseif strcmp(MainInput.AnalysisType,'Diffusion')
    MainInput.SegmentVessels = 0; % 0 || 1
elseif strcmp(MainInput.AnalysisType,'GasExchange')
    MainInput.SegmentVessels = 0; % 0 || 1
end

MainInput.vesselImageMode = 'xenon'; % xenon || proton
MainInput.SliceOrientation = 'coronal';
switch MainInput.vesselImageMode
    case 'xenon'
        MainInput.frangi_thresh = 0.25;
    case 'proton'  
        MainInput.frangi_thresh = 0.2; % you can change this threshold to increase or decrease the mask
end

if strcmp(MainInput.AnalysisType,'Ventilation')  
    if MainInput.SegmentVessels == 1
        [Ventilation] = Segmentation.Vasculature_filter(Proton, Ventilation, MainInput);
    else
        Ventilation.VesselMask = zeros(size(Ventilation.Image));
        Ventilation.vessel_stack = zeros(size(Ventilation.Image));
    end
    maskarray = double(Ventilation.LungMask + Ventilation.VesselMask);
    maskarray(maskarray > 1) = 0;
    Ventilation.LungMask = double(maskarray);
    Ventilation.LungMaskOriginal = Ventilation.LungMask;
    % figure; Global.imslice(Ventilation.VesselMask)
end

if strcmp(MainInput.AnalysisType,'Ventilation')                
    figure; Global.imslice(Ventilation.LungMask)
elseif strcmp(MainInput.AnalysisType,'Diffusion')
    figure; Global.imslice(Diffusion.LungMask)
elseif strcmp(MainInput.AnalysisType,'GasExchange')
    figure; Global.imslice(GasExchange.LungMask)
end

if ~isfield(Diffusion, 'AirwayMask')
    disp('Diffusion.AirwayMask does not exist');
else
    disp('Diffusion.AirwayMask exists');
end

if ~exist('Diffusion.AirwayMask','var')
    disp('airway mask not found')
else
    disp('airway mask found')
end

%% Ventilation analysis
clc
close all;
cd(MainInput.XeDataLocation)

% diary LogFile_LoadingData
Ventilation.N4Analysis = 0;
Ventilation.IncompleteThresh = 60;
Ventilation.RFCorrect = 0;
Ventilation.CompleteThresh = 15; %Ventilation.IncompleteThresh/2;
Ventilation.HyperventilatedThresh = 200;
Ventilation.HeterogeneityIndex = 'yes';
Ventilation.ThreshAnalysis = 'no'; % 'yes'; || 'no'
Ventilation.LB_Analysis = 'no'; % 'yes'; || 'no'
Ventilation.LB_Normalization = 'percentile'; % 'mean'; || 'median' || 'percentile'            
Ventilation.Kmeans = 'yes';  % 'yes'; || 'no'
Ventilation.AKmeans = 'no';  % 'yes'; || 'no'
Ventilation.DDI2D = 'no';  % 'yes'; || 'no'
Ventilation.DDI3D = 'no';  % 'yes'; || 'no'
Ventilation.ImageResolution = [3, 3, 15];
MainInput.PixelSpacing = Ventilation.ImageResolution(1:2);
MainInput.SliceThickness = Ventilation.ImageResolution(3);
Ventilation.DDIDefectMap = 'Threshold';  % 'Threshold'; || 'Linear Binning' || 'Kmeans'
Ventilation.GLRLM_Analysis = 'no'; % 'yes'; || 'no'

switch Ventilation.LB_Normalization
    case 'mean'
        Ventilation.Thresholds = [0.33, 0.66, 1, 1.33, 1.66];  % mean
        Ventilation.Hdist = [3.001911, 0.571907, 0.642521];
    case 'median'
        Ventilation.Thresholds = [0.373575, 0.64127, 1.001436, 1.463481, 2.036159];  % median
        Ventilation.Hdist = [3.001911, 0.571907, 0.642521]; 
    case 'percentile'
        Ventilation.Thresholds = [0.142408, 0.288563, 0.471081, 0.685923, 0.930321]; % percentile
        Ventilation.Hdist = [2.31181, 0.271049, 0.293436]; 
end 


[Ventilation] = VentilationFunctions.Ventilation_Analysis(Ventilation, Proton, MainInput);

%%  Diffusion analysis
clc
cd(MainInput.XeDataLocation)
% diary Log.txt
MainInput.PatientAge = '7';
Diffusion.ADCFittingType = 'Log Weighted Linear'; % 'Log Weighted Linear' | 'Log Linear' | 'Non-Linear' | 'Bayesian'
Diffusion.ADCAnalysisType = 'human'; % human | animals;  % human | animals
% Diffusion.bvalues = '[0, 6.25, 12.5, 18.75, 25]';
Diffusion.bvalues = '[0, 7.5, 15]';
% Diffusion.bvalues = '[0, 10, 20, 30]'; % for T-Scanner

Diffusion.ADCLB_Analysis = 'yes'; % 'yes'; || 'no'
Diffusion.ADCLB_RefMean = '0.0002*age+0.029'; 
Diffusion.ADCLB_RefSD = '5e-5*age+0.0121'; 

Diffusion.MorphometryAnalysis = 'yes';  % yes || no
Diffusion.MorphometryAnalysisType = 'human'; % human | animals
Diffusion.MA_WinBUGSPath = 'C:\Users\BAS8FL\Desktop\WinBUGS14';
Diffusion.CMMorphometry = 'no';  % yes || no
Diffusion.SEMMorphometry = 'no';  % yes || no
Diffusion.Do = 0.14; % cm2/s
Diffusion.Delta = 3.5; % ms

[Diffusion] = DiffusionFunctions.Diffusion_Analysis(Diffusion,MainInput);

% diary off
%% Gas Exchange analysis
clc;
cd(MainInput.XeDataLocation)
% diary Log.txt
if MainInput.NoProtonImage == 1
    Proton.Image = zeros(size(GasExchange.VentImage));
    Proton.ProtonRegistered = zeros(size(GasExchange.VentImage));
    Proton.ProtonMaskRegistred = GasExchange.LungMask;
end

MainInput.ImportHealthyCohort = 0; % 0: import CCHMC healthy Ref., 1: import .mat H. Ref., 2: enter values manually
if MainInput.ImportHealthyCohort == 0
    MainInput.HealthyReferenceType = 'Default';
elseif MainInput.ImportHealthyCohort == 1
    GasExchange.ImportHealthyCohort = 'yes';
    [filename, path] = uigetfile('*.mat*','Import Healthy Cohort');
    GasExchange.HealthyCohortFullPath = [path,filename];
    GasExchange.HealthyCohortDataLocation = path(1:end-1);
    [~,~,HealthyCohort_ext] = fileparts(GasExchange.HealthyCohortFullPath);
    GasExchange.HealthyCohortFileName = filename;
    GasExchange.HealthyCohort_ext = HealthyCohort_ext;
    MainInput.HealthyReferenceType = 'Import';
elseif MainInput.ImportHealthyCohort == 2
    GasExchange.VentHealthyMean = 0.51; GasExchange.VentHealthyStd = 0.19;%6
    GasExchange.DissolvedHealthyMean = 0.0075; GasExchange.DissolvedHealthyStd = 0.00125;%6
    GasExchange.BarrierHealthyMean = 0.0049; GasExchange.BarrierHealthyStd = 0.0015;%6
    GasExchange.RBCHealthyMean = 0.0026; GasExchange.RBCtHealthyStd = 0.0010;%6
    GasExchange.RBCBarrHealthyMean = 0.53; GasExchange.RBCBarrHealthyStd = 0.18;%6
    GasExchange.RBCOscHealthyMean = 8.9596; GasExchange.RBCOscHealthyStd = 10.5608;%6
    MainInput.HealthyReferenceType = 'Manual';
end

[GasExchange] = GasExchangeFunctions.GasExchange_Analysis(GasExchange,Proton,MainInput);

disp('Analysis done')
% diary off

%% patient report
clc
MainInput.studyID = '740H';
MainInput.studyType = 'CF';
MainInput.patientID = '001';
MainInput.scanDate = '7/6/2023';
MainInput.xeDoseVolume = '1000';
MainInput.PatientName = 'test test';
MainInput.MRMnumber = '1201201';
MainInput.sex = 'M';
MainInput.age = '25';
MainInput.height = '180';
MainInput.weight = '200';
MainInput.summaryofFindings = 'all good';
MainInput.notes = 'all good';
MainInput.dataAnalyst = 'ASB';
MainInput.processingDate = '7/6/2023';

Global.PatientReport(MainInput)


%% 









