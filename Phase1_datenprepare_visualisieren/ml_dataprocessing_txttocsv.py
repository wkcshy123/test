"""
Daten von der .txt* Datei nach .csv* Datei transformieren und anschliessend in bestimmter Position abspeichern

"""

import datetime
import os
import numpy as np
from pandas import DataFrame


def ml_data_processing_txt2cav(path):
    folder_path = path
    folder_name = os.listdir(folder_path)
    # konvertieren anfangen
    for folder in folder_name[1:]:
        file_path = folder_path + '\\' + folder
        print('working on ' + folder)
        file_name = os.listdir(file_path)
        txt_file_name = []

        # Die Windturbine Datei heraussuchen
        for file in file_name:
            if (os.path.splitext(file)[1] == '.txt') and (file[0] == 'W'):
                txt_file_name.append(file)

        for txt_file in txt_file_name:
            list_data = []
            # Daten Zeileweise ablesen
            with open(file_path + '\\' + txt_file, 'r') as df:
                for line in df:
                    if line.count('\n') == len(line):
                        continue
                    # die Parameterzeile durch ";" zerlegen
                    for kv in [line.strip().split(';')]:
                        list_data.append(kv)

            # Die Parameternamen ablesen naemlich die erste Zeile der Textdaten
            for i, x in enumerate(list_data[0]):
                list_data[0][i] = eval(list_data[0][i])

            # die Daten zeilweise ablesen
            row_data = []
            for i, row in enumerate(list_data[1:]):
                b = []
                for j, element in enumerate(row):
                    if j == 0:
                        # die Datumvariabel konvertieren
                        d = datetime.datetime.strptime(element, "%d.%m.%Y %H:%M:%S")
                        b.append(d)
                    else:
                        try:
                            # die Komma erst nach Punkt konvertieren
                            b.append(float(element.replace(',', '.')))
                        except ValueError:
                            # fuer Leerwerten mit NaN ergaentzen
                            b.append(np.nan)
                # Ablesen einer Zeile fertig
                row_data.append(b)

            # Ein Datenframework bilden
            frame = DataFrame(row_data, columns=list_data[0])
            # nach PCTimeStamp die Daten sortieren
            frame.sort_values(by="PCTimeStamp", ascending=True, inplace=True)
            # Daten abspeichern
            if folder.split(sep=' - ')[0][-1] == '1':
                frame.to_csv('E:\\csv_data_group_8\\Workpart1_WTG' + '\\' + txt_file.split(sep='.')[0] + '.csv',
                             na_rep='NA')
            elif folder.split(sep=' - ')[0][-1] == '2':
                frame.to_csv('E:\\csv_data_group_8\\Workpart2_WTG' + '\\' + txt_file.split(sep='.')[0] + '.csv',
                             na_rep='NA')

            print('saved ' + txt_file.split(sep='.')[0])

    print('fertig konvertiert!')
