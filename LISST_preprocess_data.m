function [cfg, data_pre, meta_pre] = LISST_preprocess_data(cfg, data_raw, meta_raw)
%% function LISST_processing_workflow
%  Syntax: 
%     [cfg, data_pre, meta_raw] = LISST_preprocess_data(cfg, data_raw, meta_raw)
%
%  Description:
%    "Preprocesses" LISST data. 
%    1. Defines new structures "meta_pre" and "data_pre"
%    2. Calculates date (matlab's datenum format) 
%    3. Calculates temperatuer and depth based on lisst.ini file contents
%    4. Reads in CTD data ** subsequent steps much easier if this is upcast
%       and downcast data with true timestamp!
%    5. Matches LISST profile to CTD cast #
%    6. Corrects LISST depth and time based on CTD data
%    7. Identifies limits of downcast (decending) in LISST profile
%    8. Saves data to cfg.path.file_pre
%
%  Refereces:
%    http://www.sequoiasci.com/article/processing-lisst-100-and-lisst-100x-data-in-matlab/
%    LISST-Deep-Users-Manual-May-2013.pdf
%    http://www.sequoiasci.com/article/how-lisst-instruments-measure-the-size-distribution-and-concentration-of-particles/
%
%  Notes:
%
%  Authors:
%    Brita K Irving  <bkirving@alaska.edu>
%% 1 | Initialize data and meta structures
data_pre = data_raw; % structure containing data
meta_pre = meta_raw; % structure containing the same fields as data with variable name descriptions and units

%% 2 | Calculate date
fprintf('Calculating date\n')
data_pre.date     = datenumfromdata(cfg.year,data_pre.data(:,39:40));
data_pre.datetime = datetime(data_pre.date,'ConvertFrom','datenum');

% update meta
meta_pre.date.name     = 'MATLAB datenum';
meta_pre.date.unit     = 'Number of days since 0-Jan-0000';
meta_pre.datetime.name = 'MATLAB datetime';
meta_pre.datetime.unit = 'scalar datetime array corresponding to the date and time';

%% 3 | Calculate temperature and depth
fprintf('Calculating temperature and depth\n')
% First, load necessary offsets and scales from ini file
instfield   = ['instrument' num2str(cfg.inst.LISSTsn)];
tempScale   = str2double(cfg.inst.ini.(instfield).hk5scale); % HK5Scale: temperature multiplier for calibration of temperature.
tempoffset  = str2double(cfg.inst.ini.(instfield).hk5off);   % HK5Off:   temperature pffset for calibration of temperature.
depthScale  = str2double(cfg.inst.ini.(instfield).hk4scale); % HK4Scale: pressure scales for calibration of pressure sensor. Look it up in LISST.INI for your serial #.
depthoffset = str2double(cfg.inst.ini.(instfield).hk4off);   % HK4Off:   pressure offsets for calibration of pressure sensor. Look it up in LISST.INI for your serial #.
% Calculate temperature and depth
data_pre.temp  = data_pre.data(:,38)*tempScale+tempoffset;
data_pre.depth = data_pre.data(:,37)*depthScale+depthoffset;
  
% update meta
meta_pre.temp.name  = 'temperature measured in endcap (therefore may have signficiant lag)';
meta_pre.temp.unit  = 'degC';
meta_pre.depth.name = 'depth calibrated using factory supplied constants from LISST.INI file';
meta_pre.depth.unit = 'm';

%% 4 | Read CTD data
if exist(cfg.path.file_ctddata,'file')
  fprintf('Loading CTD data from %s\n',cfg.path.file_ctddata)
  load(cfg.path.file_ctddata)
elseif exist(fullfile(cfg.path.dir_ctd,[cfg.project '_CTD.mat']),'file')
  cfg.path.file_ctddata = fullfile(cfg.path.dir_ctd,[cfg.project '_CTD.mat']);
  load(cfg.path.file_ctddata)
else
  ctd = read_ctd_data_by_type(cfg.ctd_type,cfg.path.dir_ctd);
end
if ~isfield(ctd,'station')
  fprintf('ADD STATION!\n')
  keyboard
end
% Calculate depth from pressure and latitude
if ~isfield(ctd,'depth')
  ctd.depth = -1*gsw_z_from_p(ctd.press,ctd.lat);
end

%% 5 | Match LISST profile to CTD sequential cast number
[cfg, data_pre, meta_pre] = LISST_match_ctd_cast(cfg, data_pre, meta_pre, ctd);

%% 6 | Correct time and depth lag
[cfg, data_pre, meta_pre] = LISST_correct_time_depth_lag(cfg,data_pre, meta_pre,ctd);

%% 7 | Limit data to downcast
[cfg, data_pre, meta_pre] = LISST_identify_downcast(cfg,data_pre,meta_pre,ctd);

%% 8 | Save data_pre and meta_pre structures 
fprintf('Saving preprocessed data to file: %s\n',cfg.path.file_pre)
save(cfg.path.file_pre,'cfg','data_pre','meta_pre');
end %% MAIN FUNCTION