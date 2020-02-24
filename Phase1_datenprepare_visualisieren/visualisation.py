"""
Die Daten visualisieren

interval_reg: input: DataFrame, Frequenz der linearregression.
              output: Zeichnung der Parameter in einem Bild
normal_draw: input: DataFrame
             output: Zeichnung der Parameter in einem Bild

"""

import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns

sns.set(color_codes=True)


# linear-Regression nach bestimmten Zeitfrequenz zeichnen
def interval_reg(df, freq):
    for j in range(int(round((len(df.keys()) - 1) / 2)) * 2 - 1):
        plt.subplot(int(round((len(df.keys()) - 1) / 2)), 2, j+1)
        df['date_f'] = pd.factorize(df.index)[0]
        parameter = df.keys()[j+1]
        mapping = dict(zip(df['date_f'], df['PCTimeStamp'].dt.date))
        # die Zeitinterval einstellen
        timeval = pd.period_range(start=df.PCTimeStamp[0], end=df.PCTimeStamp[len(df.PCTimeStamp)-1], freq=freq)
        # index anpassen
        df.index = df['PCTimeStamp']
        
        for i, date in enumerate(timeval):
            try:
                # Anfangsdatum definieren
                sta = '%02d' % timeval[i].start_time.year + '-' + '%02d' % timeval[i].start_time.month + '-' + '%02d' % timeval[i].start_time.day
                # Enddatum definieren
                end = '%02d' % timeval[i + 1].start_time.year + '-' + '%02d' % timeval[i + 1].start_time.month + '-' + '%02d' % timeval[i + 1].start_time.day
                # die Kurven Zeichnen
                ax = sns.regplot(x='date_f', y=parameter, data=df[sta:end],
                                 robust=False, truncate=True,
                                 scatter=True, scatter_kws={'s': 10, 'alpha': 0.01})
                # Die Labeln und Titeln einstellen
                labels = pd.Series(ax.get_xticks()).map(mapping).fillna('')
                ax.set_xticklabels(labels, fontsize=10)
                ax.set_xlabel('')
                ax.set_ylabel('')
                ax.set_title(parameter, fontsize=10)
            except IndexError:
                break
    return plt.gca()


# normale zeitliche verlauf
def normal_draw(df):
    fig, axes = plt.subplots(int(round((len(df.keys()) - 1) / 2)), 2, figsize=(50, 30))
    plt.subplots_adjust(wspace=0.3, hspace=0.5)
    ax = axes.ravel()
    # auf der subplot ploten
    for i in range(int(round((len(df.keys()) - 1) / 2)) * 2 - 1):
        ax[i].plot(df['PCTimeStamp'], df[df.keys()[i + 1]].values)
        ax[i].set_xlabel('')
        ax[i].set_title(df.keys()[i + 1])
    return plt.gca()
