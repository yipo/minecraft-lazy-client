@ECHO OFF
PATH %PATH%;C:\MinGW\bin;%~dp0\tool
CD /D %~dp0
mingw32-make %~n1
IF NOT ERRORLEVEL 1 ECHO [Done]
PAUSE
