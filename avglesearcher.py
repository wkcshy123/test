# -*- coding: utf-8 -*-
import os
import re
import pandas as pd
import requests
from sqlalchemy import create_engine
import random
import datetime


class AvgleSearcher:
    def __init__(self, begriff, page_zahl, database, password, table):
        self.database = database
        self.table = table
        self.engine = create_engine('mysql+pymysql://root:' + password + '@127.0.0.1:3306/', echo=False)
        self.begriff = begriff
        self.page_zahl = page_zahl

    def databaseEstablish(self):
        try:
            conn = self.engine.connect()
        except Exception as e:
            print('password false!')

        databasenames = str(conn.execute("show databases").fetchall())
        p1 = re.compile(r'[(][\'](.*?)[\'][,)]', re.S)  # 最小匹配
        databaseList = re.findall(p1, databasenames)
        if self.database not in databaseList:
            sql = "CREATE DATABASE " + self.database
            sql1 = "ALTER DATABASE " + self.database + " character set utf8"
            conn.execute(sql)
            conn.execute(sql1)

    def tableEstablish(self):
        try:
            conn = self.engine.connect()
        except Exception as e:
            print('password false!')

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
                     update_date       date       null, 
                     constraint uni
                        unique (vid))"""
            conn.execute(sql)

    def search(self):
        video_list = pd.DataFrame()
        today = datetime.date.today()
        for word in self.begriff:
            for i in range(self.page_zahl):
                collection = requests.get('https://api.avgle.com/v1/search/' + word + '/' + str(i),
                                          headers=random_header()).json()
                if collection['response']['has_more']:
                    response = pd.DataFrame(collection['response']['videos'])
                    response['search_keyword'] = word
                    response['update_date'] = today
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
                print('data already exist', flush=True)
                pass
        print("{} were found".format(i))


class Analyser:
    def __init__(self, database, password, table, searchkeywords, filepath):
        self.database = database
        self.table = table
        self.search_keywords = searchkeywords
        self.engine = create_engine('mysql+pymysql://root:'
                                    + password + '@127.0.0.1:3306/' + self.database, echo=False)
        self.rootpath = filepath

    def GetDataFromDatabase(self):
        conn = self.engine.connect()
        sql = "USE " + self.database
        sql2 = "SHOW COLUMNS FROM " + self.table
        conn.execute(sql)
        data = pd.DataFrame()
        for word in self.search_keywords:
            sql1 = "SELECT * FROM " + self.table + " WHERE search_keyword='" + word + "'"
            data = data.append(pd.DataFrame(conn.execute(sql1).fetchall()))

        columnsname_row_list = conn.execute(sql2).fetchall()
        columnsnames = [x[0] for x in columnsname_row_list]
        data.columns = columnsnames
        return data

    def downloadPicture(self):
        data = Analyser.GetDataFromDatabase(self)
        headers = random_header()
        generator = (x for x in self.search_keywords)
        for n in generator:
            mkdir(self.rootpath + "/" + n)
        for folder, name, url, update_date in zip(data['search_keyword'], data['title'],
                                                  data['preview_url'], data['update_date']):
            name = eval(repr(name).replace('/', '!'))
            filepath1 = self.rootpath + '/' + folder + '/' + name + '---' + str(update_date) + '.jpg'
            if not os.path.exists(filepath1):
                with open(filepath1, 'wb') as f:
                    f.write(requests.get(url, headers).content)
                    print('downloaded', flush=True)
            else:
                print('picture already exist', flush=True)


def random_header():
    headers_list = [
        'Mozilla/5.0 (iPhone; CPU iPhone OS 11_0 like Mac OS X) AppleWebKit/604.1.38 (KHTML, like Gecko) '
        'Version/11.0 Mobile/15A372 Safari/604.1',
        'Mozilla/5.0 (MeeGo; NokiaN9) AppleWebKit/534.13 (KHTML, like Gecko) NokiaBrowser/8.5.0 Mobile Safari/534.13',
    ]
    return {
        'cookie': "ua=237aa6249591b6a7ad6962bc73492c77; platform_cookie_reset=pc; platform=pc; "
                  "bs=kkfbi66h9zevjeq5bt27j0rvno182xdl; ss=205462885846193616; RNLBSERVERID=ded6699",
        'user-agent': random.choice(headers_list)
    }


def mkdir(path):
    folder = os.path.exists(path)

    if not folder:  # 判断是否存在文件夹如果不存在则创建为文件夹
        os.makedirs(path)  # makedirs 创建文件时如果路径不存在会创建这个路径
        print("---  new folder...  ---")
        print("---  OK  ---")
    else:
        print("---  There is this folder!  ---")


if __name__ == '__main__':
    begriff = ['上原亜衣', '有坂深雪', '波多野結衣', '橋本ありな']  # list
    page_zahl = 1  # int
    database = 'wkcshy3'  # str
    table = 'av'  # str
    password = '1234'  # str
    searcher = AvgleSearcher(begriff, page_zahl, database, password, table)
    searcher.databaseEstablish()
    searcher.tableEstablish()
    searcher.upload_in_mysql()
    print('fertig!')
    
    filepath = '/Users/zf/Downloads/av'
    analyser = Analyser(database, password, table, begriff, filepath)

    analyser.downloadPicture()
