import re
import pandas as pd
import requests
from sqlalchemy import create_engine


class AvgleSearcher:
    def __init__(self, begriff, page_zahl, database, password, table):
        self.database = database
        self.table = table
        self.engine = create_engine('mysql+pymysql://root:' + password + '@127.0.0.1:3306/', echo=False)
        self.begriff = begriff
        self.page_zahl = page_zahl

    def databaseEstablish(self):
        conn = self.engine.connect()
        databasenames = str(conn.execute("show databases").fetchall())
        p1 = re.compile(r'[(][\'](.*?)[\'][,)]', re.S)  # 最小匹配
        databaseList = re.findall(p1, databasenames)
        if self.database not in databaseList:
            sql = "CREATE DATABASE " + self.database
            sql1 = "ALTER DATABASE " + self.database + " character set utf8"
            conn.execute(sql)
            conn.execute(sql1)

    def tableEstablish(self):
        conn = self.engine.connect()
        conn.execute("USE " + self.database)

        tablelist = conn.execute("show tables").fetchall()
        if self.table not in (a[0] for i, a in enumerate(tablelist)):
            sql = """CREATE TABLE """ + self.table + """ (
                     title             text       null,
                     keyword           text       null,
                     channel           text       null,
                     duration          double     null,
                     framerate         double     null,
                     hd                tinyint(1) null,
                     addtime           bigint     null,
                     viewnumber        double     null,
                     likes             double     null,
                     dislikes          double     null,
                     video_url         text       null,
                     embedded_url      text       null,
                     preview_url       text       null,
                     preview_video_url text       null,
                     private           tinyint(1) null,
                     vid               double     null,
                     uid               text       null,
                     search_keyword    text       null,
                     constraint uni
                        unique (vid))"""
            conn.execute(sql)

    def search(self):
        video_list = pd.DataFrame()
        for word in self.begriff:
            for i in range(self.page_zahl):
                collection = requests.get('https://api.avgle.com/v1/search/' + word + '/' + str(i)).json()
                if collection['response']['has_more']:
                    response = pd.DataFrame(collection['response']['videos'])
                    response['search_keyword'] = word
                    video_list = video_list.append(response, ignore_index=True)
                else:
                    print('page out of range at {}'.format(i), flush=True)
                    break
        return video_list

    def upload_in_mysql(self):
        videolist = AvgleSearcher.search(self)
        for i in videolist.index:
            row = videolist.iloc[i:i + 1, :]
            try:
                row.to_sql(self.table, con=self.engine,
                           schema=self.database, index=False, if_exists='append')
                print('success!', flush=True)
            except Exception as e:
                print('already exist', flush=True)
                pass
        print("{} were found".format(i))

class Analyser:
    def __init__(self, database, password, table):
        self.database = database
        self.table = table
        self.engine = create_engine('mysql+pymysql://root:' 
        	+ password + '@127.0.0.1:3306/' + self.database, echo=False)

    def GetData(self):




if __name__ == '__main__':
    begriff = ['上原亜衣', '有坂深雪', '波多野結衣', '橋本ありな']  # list
    page_zahl = 999  # int
    database = 'wkcshy2'  # str
    table = 'av'  # str
    password = '1234'  # str
    searcher = AvgleSearcher(begriff, page_zahl, database, password, table)
    searcher.databaseEstablish()
    searcher.tableEstablish()
    searcher.upload_in_mysql()
    print('fertig!')






