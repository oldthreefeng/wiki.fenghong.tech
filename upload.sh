#!/bin/bash
#
#********************************************************************
#Author:			LouiseHong
#QQ: 				992165098
#Date: 				2018-06-12
#FileName：			upload.sh
#URL: 				http://blog.51cto.com/13698281
#Description：		The test script
#Copyright (C): 	2018 All rights reserved
#********************************************************************
simiki g &&  rsync -e 'ssh -p 9527' -v -r /app/wiki/output/*  root@149.28.37.72:/wiki/output
