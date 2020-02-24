clear
clc
close all
load WTGx.mat
load time_lstm_train_test.mat
%Ein Regressionmodell auf Basis der Turbine 3 trainieren, darin sind Daten im Zeitraum 2011-2013
%Zustand in diesem Zeitraum wird als gesund angenommen und deswegen als Trainingsdatensatz verwendet

%% Die Trainierungsdaten und Testdaten vorbereiten
t_train1 = datetime(2011,01,01); 
t_train2 = datetime(2013,01,01);

t_test1 = datetime(2013,4,01);
t_test2 = datetime(2016,5,23);
 
[data_train,time_train] = dataprepare(t_train1, t_train2, WTG3, 'train'); % Trainierungsdaten vorbereiten
[data_test,time_test] = dataprepare(t_test1, t_test2, WTG3, 'test');      % Testdaten vorbereiten

%% Train network mit 6 Parametern, Windspeed, Enviroment Temprature, Generater Bearing Temprature, Power, Rotor RPM, Generator RPM
[trainedModel, validationRMSE] = trainRegressionModel(data_train);

%% Resultat plotten
y_fit = trainedModel.predictFcn(data_test);                               % vorhersagen zu den Testdaten treffen
y_test = data_test.Gear_Bear_Temp_Avg;                                    % Testdaten

ypred = timetable(time_test, y_fit);                                      % f¨¹r Anschaulichkeit werden die Daten in die Tabellenform gebracht
ytest = timetable(time_test, y_test);                                     % f¨¹r Anschaulichkeit werden die Daten in die Tabellenform gebracht

figure 
diff_test_und_fit = -y_fit+data_test.Gear_Bear_Temp_Avg;                  % Differenz von Predictivwerten und Testwerten berechnen
diff_test_und_fit = smoothdata(diff_test_und_fit,'rlowess',240);          % Datenpunkt gl?ten
vars = {{'y_fit','y_test'},'diff_test_und_fit'};
stackedplot(timetable(time_test,y_fit,y_test,diff_test_und_fit),vars);    % Daten plotten
xlabel('Timestep')
title('Gear Bear Temprature')

%% Modell Speichern 
save('E:\Matlab Code\Phase2_modellbilden\RUL_demo_regression_lerner\Regressionmodel.mat','trainedModel');
disp('fertig!')

%% Inputdaten f¨¹r das weitere RUL-vorhersagen vorbereiten (Das Abnormalit?tsbereich aus dem Zeitlichen Verlauf per Augen ablsen und herausnehmen, die als Run-to-failure Daten betrachtet werden)
for i = 1:size(date,1)
    disp(i)
    t_start = datetime(date(i,6),date(i,2),date(i,3)); 
    t_end = datetime(date(i,7),date(i,4),date(i,5));
    eval(['[data_test,time_test] = dataprepare(t_start,t_end,WTG',num2str(date(i,1)),',"test");']);
    y_fit = trainedModel.predictFcn(data_test);                           % vorhersagen zu den Testdaten treffen
    y_test = data_test.Gear_Bear_Temp_Avg;                                % Testdaten
    diff_test_und_fit = filloutliers(-y_fit+y_test,'nearest','mean');     % Differenz von Predictivwerten und Testwerten berechnen
    table = timetable(time_test,diff_test_und_fit,y_test);                % Die Daten werden in die Tabelleform gebracht 
    xdata{i} = table; 
end

%% Daten abspeichern
save('E:\Matlab Code\Phase2_modellbilden\data\xdata_predictiv_maintenance_toolbox_und_lstm.mat','xdata');
disp('fertig!')