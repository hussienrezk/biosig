function [signal,H] = sload(FILENAME,CHAN)
% SLOAD loads signal data of various data formats
% 
% Currently are the following data formats supported: 
%    EDF, CNT, EEG, BDF, GDF, BKR, MAT(*), 
%    PhysioNet (MIT-ECG), Poly5/TMS32, SMA, RDF, CFWB,
%    Alpha-Trace, DEMG, SCP-ECG.
%
% [signal,header] = sload(FILENAME [,CHANNEL])
%
% FILENAME      name of file
% channel       list of selected channels
%               default=0: loads all channels
%
% see also: SOPEN, SREAD, SCLOSE, MAT2SEL, SAVE2TXT, SAVE2BKR
%

%	$Revision: 1.13 $
%	$Id: sload.m,v 1.13 2004-02-23 18:55:27 schloegl Exp $
%	Copyright (C) 1997-2004 by Alois Schloegl 
%	a.schloegl@ieee.org	
%    	This is part of the BIOSIG-toolbox http://biosig.sf.net/

% This library is free software; you can redistribute it and/or
% modify it under the terms of the GNU Library General Public
% License as published by the Free Software Foundation; either
% Version 2 of the License, or (at your option) any later version.
%
% This library is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
% Library General Public License for more details.
%
% You should have received a copy of the GNU Library General Public
% License along with this library; if not, write to the
% Free Software Foundation, Inc., 59 Temple Place - Suite 330,
% Boston, MA  02111-1307, USA.

if nargin<2; CHAN=0; end;

if CHAN<1 | ~isfinite(CHAN)
        CHAN=0;
end;

if isstruct(FILENAME),
        HDR=FILENAME;
        if isfield(HDR,'FileName'),
                FILENAME=HDR.FileName;
        else
                fprintf(2,'Error LOADEEG: missing FileName.\n');	
                return; 
        end;
end;

[p,f,FileExt] = fileparts(FILENAME);
FileExt = FileExt(2:length(FileExt));
H.FileName = FILENAME;
H = sopen(H,'rb',CHAN);

if strcmp(H.TYPE,'SCPECG'),
        signal = H.SCP.data;
        return;
        
elseif H.FILE.FID>0,
        [signal,H] = sread(H);
        H = sclose(H);

elseif strcmp(H.TYPE,'alpha'),
        if ~any(H.VERSION==[407.1,409.5]);
                fprintf(2,'Warning SLOAD: Format ALPHA Version %6.2f not tested yet.\n',H.VERSION);
        end;
        
        fid = fopen(fullfile(p,'rawdata'),'rb');
        if fid > 0,
                H.VERSION2  = fread(fid,1,'int16');
                H.NS   = fread(fid,1,'int16');
                H.bits = fread(fid,1,'int16');
                H.AS.bpb = H.NS*H.bits/8;
                
                if H.bits==12,
                        s = fread(fid,[3,inf],'uint8');
                        s(1,:) = s(1,:)*16 + floor(s(2,:)/16); 	
                        s(3,:) = s(3,:)+ mod(s(2,:),16)*256; 	
                        s = reshape(s([1,3],:),1,2*size(s,2));
                        signal = reshape(s(1:H.NS*H.SPR),H.NS,H.SPR)';
                        signal = signal-(signal>=2^11)*2^12;
                elseif H.bits==16,
                        s = fread(fid,[H.NS,inf],'int16');
                        signal = reshape(s(1:H.NS*H.SPR),H.NS,H.SPR)';
                elseif H.bits==32,
                        s = fread(fid,[H.NS,inf],'int32');
                        signal = reshape(s(1:H.NS*H.SPR),H.NS,H.SPR)';
                end;        
                fclose(fid);
                if CHAN==0,
                        CHAN = 1:H.NS;
                end;
                signal = [ones(size(signal,1),1),signal] * H.Calib(:,CHAN);
                % signal = signal * diag(H.Cal);
        end;
        
        
elseif strcmp(H.TYPE,'DAQ')
	fprintf(1,'Loading a matlab DAQ data file - this can take a while.\n');
	tic;
 	[signal, tmp, H.DAQ.T0, H.DAQ.events, DAQ.info] = daqread(H.FileName);
	fprintf(1,'Loading DAQ file finished after %.0f s.\n',toc);
	H.NS   = size(signal,2);
        
	H.SampleRate = DAQ.info.ObjInfo.SampleRate;
        sz     = size(signal);
        if length(sz)==2, sz=[1,sz]; end;
        H.NRec = sz(1);
        H.Dur  = sz(2)/H.SampleRate;
        H.NS   = sz(3);
        H.FLAG.TRIGGERED = H.NRec>1;
        H.FLAG.UCAL = 1;
	
        H.PhysDim = {DAQ.info.ObjInfo.Channel.Units};
        H.DAQ   = DAQ.info.ObjInfo.Channel;
        
        H.Cal   = diff(cat(1,DAQ.info.ObjInfo.Channel.InputRange),[],2).*(2.^(-DAQ.info.HwInfo.Bits));
        H.Off   = cat(1,DAQ.info.ObjInfo.Channel.NativeOffset); 
        H.Calib = sparse([H.Off';eye(H.NS)]*diag(H.Cal));
        
        if CHAN<1,
                CHAN = 1:H.NS; 
        end;
        if ~H.FLAG.UCAL,
        	signal = [ones(size(signal,1),1),signal]*H.Calib(:,CHAN);        
        end;
        
         
elseif strncmp(H.TYPE,'MAT',3),
        tmp = load(FILENAME);
        if isfield(tmp,'y'),		% Guger, Mueller, Scherer
                H.NS = size(tmp.y,2);
                if ~isfield(tmp,'SampleRate')
                        %warning(['Samplerate not known in ',FILENAME,'. 125Hz is chosen']);
                        H.SampleRate=125;
                else
                        H.SampleRate=tmp.SampleRate;
                end;
                warning(['Sensitivity not known in ',FILENAME]);
                if any(CHAN),
                        signal = tmp.y(:,CHAN);
                else
        	        signal = tmp.y;
                end;
                
        elseif isfield(tmp,'daten');	% Woertz, GLBMT-Uebungen 2003
                H = tmp.daten;
                s = H.raw*H.Cal;
                
        elseif isfield(tmp,'eeg');	% Scherer
                warning(['Sensitivity not known in ',FILENAME]);
                H.NS=size(tmp.eeg,2);
                if ~isfield(tmp,'SampleRate')
                        %warning(['Samplerate not known in ',FILENAME,'. 125Hz is chosen']);
                        H.SampleRate=125;
                else
                        H.SampleRate=tmp.SampleRate;
                end;
                if any(CHAN),
                        signal = tmp.eeg(:,CHAN);
                else
        	        signal = tmp.eeg;
                end;
                if isfield(tmp,'classlabel'),
                	H.Classlabel = tmp.classlabel;
                end;        

        elseif isfield(tmp,'P_C_S');	% G.Tec Ver 1.02, 1.5x data format
                if isa(tmp.P_C_S,'data'), %isfield(tmp.P_C_S,'version'); % without BS.analyze	
                        if any(tmp.P_C_S.Version==[1.02, 1.5, 1.52]),
                        else
                                fprintf(2,'Warning: PCS-Version is %4.2f.\n',tmp.P_C_S.Version);
                        end;
                        H.Filter.LowPass  = tmp.P_C_S.LowPass;
                        H.Filter.HighPass = tmp.P_C_S.HighPass;
                        H.Filter.Notch    = tmp.P_C_S.Notch;
                        H.SampleRate      = tmp.P_C_S.SamplingFrequency;
                        H.gBS.Attribute   = tmp.P_C_S.Attribute;
                        H.gBS.AttributeName = tmp.P_C_S.AttributeName;
                        H.Label = tmp.P_C_S.ChannelName;
                        H.gBS.EpochingSelect = tmp.P_C_S.EpochingSelect;
                        H.gBS.EpochingName = tmp.P_C_S.EpochingName;

                        signal = double(tmp.P_C_S.Data);
                        
                else %if isfield(tmp.P_C_S,'Version'),	% with BS.analyze software, ML6.5
                        if any(tmp.P_C_S.version==[1.02, 1.5, 1.52]),
                        else
                                fprintf(2,'Warning: PCS-Version is %4.2f.\n',tmp.P_C_S.version);
                        end;        
                        H.Filter.LowPass  = tmp.P_C_S.lowpass;
                        H.Filter.HighPass = tmp.P_C_S.highpass;
                        H.Filter.Notch    = tmp.P_C_S.notch;
                        H.SampleRate      = tmp.P_C_S.samplingfrequency;
                        H.gBS.Attribute   = tmp.P_C_S.attribute;
                        H.gBS.AttributeName = tmp.P_C_S.attributename;
                        H.Label = tmp.P_C_S.channelname;
                        H.gBS.EpochingSelect = tmp.P_C_S.epochingselect;
                        H.gBS.EpochingName = tmp.P_C_S.epochingname;
                        
                        signal = double(tmp.P_C_S.data);
                end;
                tmp = []; % clear memory

                sz     = size(signal);
                H.NRec = sz(1);
                H.Dur  = sz(2)/H.SampleRate;
                H.NS   = sz(3);
                H.FLAG.TRIGGERED = H.NRec>1;
                
                if any(CHAN),
                        %signal=signal(:,CHAN);
                        sz(3)= length(CHAN);
                else
                        CHAN = 1:H.NS;
                end;
                signal = reshape(permute(signal(:,:,CHAN),[2,1,3]),[sz(1)*sz(2),sz(3)]);

                % Selection of trials with artifacts
                ch = strmatch('ARTIFACT',H.gBS.AttributeName);
                if ~isempty(ch)
                        H.ArtifactSelection = H.gBS.Attribute(ch,:);
                end;
                
                % Convert gBS-epochings into BIOSIG - Events
                map = zeros(size(H.gBS.EpochingName,1),1);
                map(strmatch('AUGE',H.gBS.EpochingName))=hex2dec('0101');
                map(strmatch('MUSKEL',H.gBS.EpochingName))=hex2dec('0103');
                map(strmatch('ELECTRODE',H.gBS.EpochingName))=hex2dec('0105');
                
                H.EVENT.N   = size(H.gBS.EpochingSelect,1);
                H.EVENT.TYP = map([H.gBS.EpochingSelect{:,9}]');
                H.EVENT.POS = [H.gBS.EpochingSelect{:,1}]';
                H.EVENT.CHN = [H.gBS.EpochingSelect{:,3}]';
                H.EVENT.DUR = [H.gBS.EpochingSelect{:,4}]';

                
	elseif isfield(tmp,'P_C_DAQ_S');
                if ~isempty(tmp.P_C_DAQ_S.data),
                        signal = double(tmp.P_C_DAQ_S.data{1});
                        
                elseif ~isempty(tmp.P_C_DAQ_S.daqboard),
                        [tmppfad,file,ext] = fileparts(tmp.P_C_DAQ_S.daqboard{1}.ObjInfo.LogFileName),
                        file = [file,ext];
                        if exist(file)==2,
                                signal=daqread(file);        
                                H.info=daqread(file,'info');        
                        else
                                fprintf(H.FILE.stderr,'Error LOADEEG: no data file found\n');
                                return;
                        end;
                        
                else
                        fprintf(H.FILE.stderr,'Error LOADEEG: no data file found\n');
                        return;
                end;
                
                H.NS = size(signal,2);
                %scale  = tmp.P_C_DAQ_S.sens;      
                H.Cal = tmp.P_C_DAQ_S.sens*(2.^(1-tmp.P_C_DAQ_S.daqboard{1}.HwInfo.Bits));
                
                if all(tmp.P_C_DAQ_S.unit==1)
                        H.PhysDim='uV';
                else
                        H.PhysDim='[?]';
                end;
                
                H.SampleRate = tmp.P_C_DAQ_S.samplingfrequency;
                sz     = size(signal);
                if length(sz)==2, sz=[1,sz]; end;
                H.NRec = sz(1);
                H.Dur  = sz(2)/H.SampleRate;
                H.NS   = sz(3);
                H.FLAG.TRIGGERED = H.NRec>1;
                H.Filter.LowPass = tmp.P_C_DAQ_S.lowpass;
                H.Filter.HighPass = tmp.P_C_DAQ_S.highpass;
                H.Filter.Notch = tmp.P_C_DAQ_S.notch;
                if any(CHAN),
                        signal=signal(:,CHAN);
                else
                        CHAN=1:H.NS;
                end; 
                if ~H.FLAG.UCAL,
			signal=signal*diag(H.Cal(CHAN));                	        
                end;
                
                
        elseif isfield(tmp,'data');	% Mueller, Scherer ? 
                H.NS = size(tmp.data,2);
                if ~isfield(tmp,'SampleRate')
                        warning(['Samplerate not known in ',FILENAME,'. 125Hz is chosen']);
                        H.SampleRate=125;
                else
                        H.SampleRate=tmp.SampleRate;
                end;
                if any(CHAN),
                        signal = tmp.data(:,CHAN);
                else
        	        signal = tmp.data;
                end;
                if isfield(tmp,'classlabel'),
                	H.Classlabel = tmp.classlabel;
                end;        

                
        elseif isfield(tmp,'EEGdata');  % Telemonitoring Daten (Reinhold Scherer)
                H.NS = size(tmp.EEGdata,2);
                H.Classlabel = tmp.classlabel;
                if ~isfield(tmp,'SampleRate')
                        warning(['Samplerate not known in ',FILENAME,'. 125Hz is chosen']);
                        H.SampleRate=125;
                else
                        H.SampleRate=tmp.SampleRate;
                end;
                H.PhysDim = '�V';
                warning(['Sensitivity not known in ',FILENAME,'. 50�V is chosen']);
                if any(CHAN),
                        signal = tmp.EEGdata(:,CHAN)*50;
                else
                        signal = tmp.EEGdata*50;
                end;
                

        elseif isfield(tmp,'daten');	% EP Daten von Michael Woertz
                H.NS = size(tmp.daten.raw,2)-1;
                if ~isfield(tmp,'SampleRate')
                        warning(['Samplerate not known in ',FILENAME,'. 2000Hz is chosen']);
                        H.SampleRate=2000;
                else
                        H.SampleRate=tmp.SampleRate;
                end;
                H.PhysDim = '�V';
                warning(['Sensitivity not known in ',FILENAME,'. 100�V is chosen']);
                %signal=tmp.daten.raw(:,1:H.NS)*100;
                if any(CHAN),
                        signal = tmp.daten.raw(:,CHAN)*100;
                else
                        signal = tmp.daten.raw*100;
                end;
                
        elseif isfield(tmp,'neun') & isfield(tmp,'zehn') & isfield(tmp,'trig');	% guger, 
                H.NS=3;
                if ~isfield(tmp,'SampleRate')
                        warning(['Samplerate not known in ',FILENAME,'. 125Hz is chosen']);
                        H.SampleRate=125;
                else
                        H.SampleRate=tmp.SampleRate;
                end;
                warning(['Sensitivity not known in ',FILENAME]);
                signal  = [tmp.neun;tmp.zehn;tmp.trig];
                H.Label = {'Neun','Zehn','TRIG'};
                if any(CHAN),
                        signal=signal(:,CHAN);
                end;        
                
        elseif isfield(tmp,'header')    % Scherer
                signal =[];
                H = tmp.header;
                
        else
                warning(['SLOAD: MAT-file ',FILENAME,' not identified as BIOSIG signal',]);
                whos('-file',FILENAME);
        end;        

elseif strcmp(H.TYPE,'unknown')
        TYPE = upper(H.FILE.Ext);
        if strcmp(TYPE,'DAT')
                loaddat;     
                signal = Voltage(:,CHAN);
        elseif strcmp(TYPE,'RAW')
                loadraw;
        elseif strcmp(TYPE,'RDT')
                [signal] = loadrdt(FILENAME,CHAN);
                Fs = 128;
        elseif strcmp(TYPE,'XLS')
                loadxls;
        elseif strcmp(TYPE,'DA_')
                fprintf('Warning LOADEEG: Format DA# in testing state and is not supported\n');
                loadda_;
        elseif strcmp(TYPE,'RG64')
                [signal,H.SampleRate,H.Label,H.PhysDim,H.NS]=loadrg64(FILENAME,CHAN);
                %loadrg64;
        else
                fprintf('Error SLOAD: Unknown Data Format\n');
                signal = [];
        end;
end;
