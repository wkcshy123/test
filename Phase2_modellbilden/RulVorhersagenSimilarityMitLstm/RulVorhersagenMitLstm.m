% eine alternative Moeglichkeit der RUL-Vorhersagen mittels LSTM-Netzwerk
% es ist naemlich ein similarity-based Ansatz
% angenommen. Die Run-to-Failure Daten sind durch AbnormalitaetErkennung.m
% schon vorhanden
clear
clc
close all
load xdata_predictiv_maintenance_toolbox_und_lstm.mat
nsample = 10;                                                              % hilfsparameter beim Zeichnen

%% ein Health-Condition bilden (nicht das Healthindex)
sensorToFuse = ["diff_test_und_fit", "y_test"];                            % einzusetzende Parameter
for j=1:numel(xdata)
    data = xdata{j};
    data = smoothdata(data,'rlowess',duration(240,0,0));
    rul = linspace(height(xdata{j}),1,height(xdata{j}))';                  % RUL definieren als L?nge der ausgew?hlten Daten
    data.health_condition = rul / max(rul);
    xdata{j} = data;
end

trainDataNormalizedUnwrap1 = vertcat(xdata{:});                            % Die Daten vereinigen, um die weitere Berechnung zu vvereinfachen

%% Die gewichtung der Parameter berechnen
X = trainDataNormalizedUnwrap1{:, cellstr(sensorToFuse)};
y = trainDataNormalizedUnwrap1.health_condition;
regModel = fitlm(X,y);
bias = regModel.Coefficients.Estimate(1);
weights = regModel.Coefficients.Estimate(2:end);

%% ein Health-index ausrechnen mittels der lineare Kombination der Parameter mit unterschiedlichen Gewichtungen
HealthIndex = cellfun(@(data) degradationSensorFusion(data, sensorToFuse, weights), xdata, ...
    'UniformOutput', false);                                               % Healthindex berechnen
helperPlotEnsemble(HealthIndex, [], 1, numel(HealthIndex))                 % Healthindex plotten
set(gca,'FontSize',20); 

%% Traindaten- und Testdatenset bilden
for i = 1:numel(xdata)-4
    data = xdata{i};
    xtrain{i} = data{:, cellstr(sensorToFuse)}';
    time_train{i} = data.time_test;
    ytrain{i} = HealthIndex{i}';
end

for i = 1:4
    data = xdata{i+numel(xdata)-4};
    xtest{i} = data{:, cellstr(sensorToFuse)}';
    time_test{i} = data.time_test;
    ytest{i} = HealthIndex{i+numel(xdata)-4}';
end

%% LSTM-Netzwerk definieren
numResponses = size(ytrain{1},1);
featureDimension = size(xtrain{1},1);                                      % Anzahl von train parameter
numHiddenUnits = 100;                                                      % Anzahl von Neurals per Layer
%% layers
layers = [ ...
    sequenceInputLayer(featureDimension)
    lstmLayer(numHiddenUnits,'OutputMode','sequence')
    lstmLayer(numHiddenUnits,'OutputMode','sequence')
    lstmLayer(numHiddenUnits,'OutputMode','sequence')
    fullyConnectedLayer(50)
    dropoutLayer(0.5)
    fullyConnectedLayer(numResponses)
    regressionLayer];

maxEpochs = 150;
miniBatchSize = 5;

%% train optionen
options = trainingOptions('adam', ...
    'MaxEpochs',maxEpochs, ...
    'MiniBatchSize',miniBatchSize, ...
    'InitialLearnRate',0.01, ...
    'LearnRateDropPeriod',125, ...
    'LearnRateDropFactor',0.5, ...
    'GradientThreshold',1, ...
    'Shuffle','never', ...
    'Plots','training-progress',...
    'Verbose',0);

%% trainierung
net = trainNetwork(xtrain,ytrain,layers,options);

%% Testdaten vorhersagen
YPred = predict(net,xtest,'MiniBatchSize',1);

%% Resultat plotten
idx = linspace(1,numel(YPred),numel(YPred));
figure
for i = 1:numel(idx)
    a = time_test{i};
    subplot(2,2,i);
    plot(a,ytest{idx(i)},'--')
    hold on
    plot(a,YPred{idx(i)},'.-')
    yticks([min(ytest{idx(i)}) mean([max(ytest{idx(i)}) min(ytest{idx(i)})]) max(ytest{idx(i)})])
    yticklabels({'100%','50%','0%'})
    hold off
   
    title("Windturbine " + idx(i))
    xlabel("Time Step")
    ylabel("Degradation")
end
legend(["Test Data" "Predicted"],'Location','southeast')
set(gca,'FontSize',20);
%save('E:\Matlab Code\Phase2_modellbilden\RUL_demo_lstm\net_exp1.mat','net');

