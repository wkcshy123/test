function [data_out,time_interval] = dataprepare(t_start, t_end, data, usecase)
%% Input
% t_start: Anfangszeit (datetime)
% t_end: Endezeit (datetime)
% data: Datentabelle (table)
% usecase: wof¨¹r die Daten genutzt wird ("train" oder "test")
%% output
% data_out: Datentabelle nach der Vorbearbeitung (table)
% time_interval: Zeitinterval der Daten (timerange)

%% HCnt_Avg_SrvOn sorgt f¨¹r Datenfiltern, dass nur die Datenpunkten ohne Service oder Stillstand als normale Betriebspunkt betrachtet werden
 % Hcnt_serviceOn und ...run werden von Normalisierung der Daten
 % ausgeschossen und erst später wieder hinzugef¨¹t
time = data.PCTimeStamp;
Hcnt_srvon = data.HCnt_Avg_SrvOn;
Hcnt_run = data.HCnt_Avg_Run;
data = removevars(data, {'HCnt_Avg_SrvOn','HCnt_Avg_Run','PCTimeStamp'});
data = filloutliers(data,'nearest','mean'); % outlier Werten gl?ten

%% 0-Werten mit vorherrige Daten ersetzen
data = fillmissing(data,'previous');                      % NaN-Werten mit verherigem Wert f¨¹llen
rownames = data.Properties.VariableNames;
for i = 1:size(data,2)
    eval(['index = find(~data.',rownames{i},');']);
    eval(['columndata = data.',rownames{i},';']);
    for j = 1:numel(index)
        eval(['columndata(',num2str(index(j)),')=nan;']); % Null Werten mit nan ersetzen
    end
    eval(['data.',rownames{i},'= columndata;']);          % Parameterdaten wieder in die Tabelle einsetzen
end
data = fillmissing(data,'previous');                      % NaN-Werten noch mal f¨¹llen

%% Die Daten wieder in die Tabelleform zur¨¹cktransormieren (f¨¹r Daten zur Trainierung bei der Abnormalit?terkennung wird zus?tzliches Filtern durchgef¨¹hrt)
data = table2timetable(data,'RowTimes',time);             % nach der Erg?zung der NaN-Werten erneut timetable bilden
data = normalize(data);                                   % Daten normalisieren

data.HCnt_Avg_SrvOn = Hcnt_srvon;                         % Nach der Normalisierung die Zustanddaten wieder hinzuf¨¹gen
data.HCnt_Avg_Run = Hcnt_run;                             % Nach der Normalisierung die Zustanddaten wieder hinzuf¨¹gen
TR = timerange(t_start,t_end);
data = data(TR,:);                                        % Datenpunkt im bestimmten Zeitraum auswaehlen

% F¨¹r die Trainingsdaten wird noch mal gefiltert, um die Datenpunkte
% w?rend eventueller Wartung herauszufiltern
if strcmp(usecase,'train')
    Srv_on = data.HCnt_Avg_SrvOn >=10;                    % Die Datenpunkt, bei dennen Wartung ¨¹ber 10 sekunden da¨¹rt
    Run_off = data.HCnt_Avg_Run <= 598;                   % Die Datenpunkt, bei dennen ¨¹ber 2 sekunden stillstehen
    to_filter = Srv_on | Run_off;                         % die betroffnen Datenpunkt gilten als nicht normale Fall
    data.Time(to_filter) = NaT;                           % die Zeitpunkt der Punkten weglassen zum Filtern
    TF = ismissing(data.Time);
    data = data(~TF,:);                                   % Daten filtern
end

time_interval = data.Time;                                % Das Zeitraum der Daten
data_out = timetable2table(data);                         % Parameter Zeit weglassen
data_out = removevars(data_out, {'Time','HCnt_Avg_SrvOn','HCnt_Avg_Run'}); % unabhangige Parameter entfernen
end