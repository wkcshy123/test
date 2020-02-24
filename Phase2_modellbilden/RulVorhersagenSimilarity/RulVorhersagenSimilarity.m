% eine alternative Moeglichkeit der RUL-Vorhersagen mittels LSTM-Netzwerk
% es ist naemlich ein similarity-based Ansatz
% angenommen. Die Run-to-Failure Daten sind durch AbnormalitaetErkennung.m
% schon vorhanden
% predictive_maintainance_toolbox ben?igt
clear
clc
close all
load xdata_predictiv_maintenance_toolbox_und_lstm.mat

nsample = 10;                                                              % hilfsparameter beim Zeichnen

%% ein Health-index bilden
sensorToFuse = ["diff_test_und_fit", "y_test"];                            % einzusetzende Parameter
for j=1:numel(xdata)
    data = xdata{j};
    t1 = data.time_test(1);
    t2 = data.time_test(end);
    t = t1:t2;
    features = table;                                                      % Featuretabelle erstellen
    for i = 1:length(t)-1
        TR1 = timerange(t(i),t(i+1));
        data_per_day{i} = data(TR1,:);                                     % Parameter im Zeitbereich 
        features.Date(i) = t(i);
        features.diff_test_und_fit(i) = filloutliers(mean(data_per_day{i}.diff_test_und_fit),'linear'); % Parameter in die Featuretabelle eintragen
        features.y_test(i) = filloutliers(mean(data_per_day{i}.y_test),'linear');                       % Parameter in die Featuretabelle eintragen
    end
    features = head(features, height(features)-round(rand(1)*20));
    rul = linspace(height(features),1,height(features))'; 
    features.health_condition = rul / max(rul);                            % Parameter in die Featuretabelle eintragen
    xdata{j} = features;
end

trainDataNormalizedUnwrap1 = vertcat(xdata{:});                            % Datenvereinigung zur Vereinfachung sp?ter

%% Die gewichtung der Parameter berechnen
X = trainDataNormalizedUnwrap1{:, cellstr(sensorToFuse)};
y = trainDataNormalizedUnwrap1.health_condition;
regModel = fitlm(X,y);
bias = regModel.Coefficients.Estimate(1); 
weights = regModel.Coefficients.Estimate(2:end);                           % Gewichtungen der Parameter

%% Health-index ausrechnen
HealthIndex = cellfun(@(data) degradationSensorFusion(data, sensorToFuse, weights), xdata, ...
    'UniformOutput', false);                                               % Heathindicator wird her erstellt
helperPlotEnsemble(HealthIndex, [], 1, numel(HealthIndex)) 

%% Traindaten- und Testdatenset bilden
for i = 1:numel(xdata)-4
    data = xdata{i};
    xtrain{i} = data{:, cellstr(sensorToFuse)};
    time_train{i,:} = data.Date;
    ytrain{i,:} = HealthIndex{i};
end

for i = 1:4
    data = xdata{i+numel(xdata)-4};
    xtest{i} = data{:, cellstr(sensorToFuse)}';
    time_test{i,:} = data.Date;
    ytest{i,:} = HealthIndex{i+numel(xdata)-4};
end

%% ein lineare Similarity Modell bilden  
mdl = residualSimilarityModel(...
    'Method', 'linear',...
    'Distance', 'absolute',...
    'NumNearestNeighbors', 10,...
    'Standardize', 1);

fit(mdl, ytrain);                                                          % Modell anpassen

%%
breakpoint = [0.5, 0.7, 0.9];
validationDataTmp = ytest{1};                                              % eine Testdaten plotten

bpidx = 1;
validationDataTmp50 = validationDataTmp(1:ceil(end*breakpoint(bpidx)),:);
trueRUL = length(validationDataTmp) - length(validationDataTmp50);
[estRUL, ciRUL, pdfRUL] = predictRUL(mdl, validationDataTmp50);

figure
subplot(2,1,1)
compare(mdl, validationDataTmp50);                                         % Vorhersagensresultat plotten
subplot(2,1,2)
helperPlotRULDistribution(trueRUL, estRUL, pdfRUL, ciRUL)                  % PDF der Vorhersage plotten