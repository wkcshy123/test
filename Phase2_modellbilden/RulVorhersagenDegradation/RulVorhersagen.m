% RUL vorhersagen durch geeignete Auswahl von Health-index
% Durch Predictiv maintenance Toolbox eine Degradationsmodell aufbauen 
% deswegen ist Predictiv maintenance Toolbox notwendig!
clear
clc
close all
%% Daten laden
load xdata_predictiv_maintenance_toolbox_und_lstm.mat

%% eine Turbinedatenreihe ausw?hlen
select_data = 3;
data_turbine = xdata{select_data};                                         % Daten von der ausgw?hlten Turbine
t1 = data_turbine.time_test(1);
t2 = data_turbine.time_test(end);
t = t1:t2;
timeUnit = 'day';                                                          % Hilfsparameter beim Zeichnen

%% Featuretabelle bilden
features = table;                                                          % Featuretabelle definieren
for i = 1:length(t)-1
    TR1 = timerange(t(i),t(i+1));
    data_per_day{i} = data_turbine(TR1,:);                                 % Parameter im Zeitbereich 
    features.Date(i) = t(i);
    features.Mean(i) = mean(data_per_day{i}.diff_test_und_fit);
    features.Std(i) = std(data_per_day{i}.diff_test_und_fit);
    features.Skewness(i) = skewness(data_per_day{i}.diff_test_und_fit);
    features.Kurtosis(i) = kurtosis(data_per_day{i}.diff_test_und_fit);
    features.Peak2Peak(i) = peak2peak(data_per_day{i}.diff_test_und_fit);
    features.RMS(i) = rms(data_per_day{i}.diff_test_und_fit);
    features.CrestFactor(i) = max(data_per_day{i}.diff_test_und_fit)/features.RMS(i);
    features.ShapeFactor(i) = features.RMS(i)/mean(abs(data_per_day{i}.diff_test_und_fit));
    features.ImpulseFactor(i) = max(data_per_day{i}.diff_test_und_fit)/mean(abs(data_per_day{i}.diff_test_und_fit));
    features.MarginFactor(i) = max(data_per_day{i}.diff_test_und_fit)/mean(abs(data_per_day{i}.diff_test_und_fit))^2;
    features.Energy(i) = sum(data_per_day{i}.diff_test_und_fit.^2);
end
featureTable = table2timetable(features);                                  % Feature zu Timetable transformieren

%% Feature smoothing/vorbehandelung
variableNames = featureTable.Properties.VariableNames;
featureTableSmooth = varfun(@(x) movmean(x, [5 0]), featureTable);
featureTableSmooth.Properties.VariableNames = variableNames;

%% Vergleich vor und nach Smoothing
figure
hold on
plot(featureTable.Date, featureTable.Mean)
plot(featureTableSmooth.Date, featureTableSmooth.Mean)
hold off
xlabel('Time')
ylabel('Feature Value')
legend('Before smoothing', 'After smoothing')
title('Mean')

%% Traindaten bilden, wobei die Traindaten hier nur zum Ausw?hlen der Feature dient (mittels Analye der Wichtigkeit der Parameter)
TrainDatenMenge = 0.3;                                                     % regeln, wie viel Daten zur Verf¨¹gung gestellt werden, um die Wichtigkeit der Parameter zu beurteilen
breaktime = featureTable.Date(round(TrainDatenMenge*height(featureTable)));
breakpoint = find(featureTableSmooth.Date < breaktime, 1, 'last');
trainData = featureTableSmooth(1:breakpoint, :);

%% Wichtigkeit der Parameter analysieren
featureImportance = monotonicity(trainData, 'WindowSize', 0);
helperSortedBarPlot(featureImportance, 'Bear'); 
importance = flip(sort(table2array(featureImportance(1,:))));

%% ausgewaehlten Feature herausnehmen
trainDataSelected = trainData(:, featureImportance{:,:} >= importance(3)); % Die ersten 3 wichtigsten Parameter ausw?hlen
featureSelected = featureTableSmooth(:, featureImportance{:,:} >= importance(3));
featureName = string(trainDataSelected.Properties.VariableNames);

meanTrain = mean(trainDataSelected{:,:});
sdTrain = std(trainDataSelected{:,:});
trainDataNormalized = (trainDataSelected{:,:} - meanTrain)./sdTrain;
coef = pca(trainDataNormalized);

%% Healthindex erstellen durch PCA Verfahren (eine Moeglichkeit)
PCA1 = (featureSelected{:,:} - meanTrain) ./ sdTrain * coef(:, 1);
PCA2 = (featureSelected{:,:} - meanTrain) ./ sdTrain * coef(:, 2);

figure
numData = size(featureTable, 1);
scatter(PCA1, PCA2, [], 1:numData, 'filled')
xlabel('PCA 1')
ylabel('PCA 2')
cbar = colorbar;

%% Healthindex erstellen durch Regressionmodell (auch eine Moeglichkeit)
rul = linspace(1,height(featureSelected),height(featureSelected))'; 
featureSelected.health_condition = rul / max(rul);
X = featureSelected{:, cellstr(featureName)};
regModel = fitlm(X,featureSelected.health_condition);
bias = regModel.Coefficients.Estimate(1);
weights = regModel.Coefficients.Estimate(2:end);
HealthIndex = degradationSensorFusion(featureSelected, featureName, weights);

%% Ein Healthindex feststellen
%healthIndicator = smooth(PCA1,10);                                        % 1. Moeglichkeit, das erste Komponente der PCA als Healthindex zu nehmen
%healthIndicator = smooth(featureTableSmooth.Mean,240);                    % 2. Moeglichkeit, eine aussageskraeftige Feature direkt als Healthindex zu nehmen
healthIndicator = HealthIndex;                                             % 3. Moeglichkeit, das Healthindex selbst zu erstellen

figure
plot(featureTableSmooth.Date, healthIndicator, '-o')
xlabel('Time')
title('Health Indicator')

healthIndicator = healthIndicator - healthIndicator(1);                    % Healthindicator ?ndert von 0 an 
threshold = healthIndicator(end);

%% Degradationsmodell bilden mit linearem oder exponentiellem Ansatz
mdl = exponentialDegradationModel(...
    'Theta', 1, ...
    'ThetaVariance', 1e7, ...
    'Beta', 1, ...
    'BetaVariance', 1e6, ...
    'Phi', -1, ...
    'NoiseVariance', (0.2*threshold/(threshold + 1))^2, ...
    'SlopeDetectionLevel', 0.05);

%% In jeder Iteration zu akutualisierten Parameter
totalDay = length(healthIndicator) - 1;
estRULs = zeros(totalDay, 1);
trueRULs = zeros(totalDay, 1);
CIRULs = zeros(totalDay, 2);
pdfRULs = cell(totalDay, 1);

figure
ax1 = subplot(2, 1, 1);
ax2 = subplot(2, 1, 2);

%% Iteration
for currentDay = 1:totalDay
    
    % aktuallisieren Modellzustand
    update(mdl, [currentDay healthIndicator(currentDay)])
    
    % RUL vorhersagen
    [estRUL, CIRUL, pdfRUL] = predictRUL(mdl, ...
                                         [currentDay healthIndicator(currentDay)], ...
                                         threshold);
    trueRUL = totalDay - currentDay + 1;
    
    % PDF zeichnen
    helperPlotTrend(ax1, currentDay, healthIndicator, mdl, threshold, timeUnit);
    helperPlotRUL(ax2, trueRUL, estRUL, CIRUL, pdfRUL, timeUnit)
    
    % Resultat der Vorhersage aufzeichnen
    estRULs(currentDay) = estRUL;
    trueRULs(currentDay) = trueRUL;
    CIRULs(currentDay, :) = CIRUL;
    pdfRULs{currentDay} = pdfRUL;
    
    pause(0.02)
end

%% Leistung des Modellsbewerten
alpha = 0.2;
detectTime = mdl.SlopeDetectionInstant;
prob = helperAlphaLambdaPlot(alpha, trueRULs, estRULs, CIRULs, ...
    pdfRULs, detectTime, breakpoint, timeUnit);
title('\alpha-\lambda Plot')
