@ECHO OFF

:: This batch file looks for installed `make' tools
:: and run it as call the `make' command directly
:: without setting the PATH environment variable permanently.

PATH %PATH%;%~dp0\tool
CD /D %~dp0

SET LIST=^
C:\MinGW\bin\mingw32-make.exe ^
C:\"Program Files"\GnuWin32\bin\make.exe ^
C:\"Program Files (x86)"\GnuWin32\bin\make.exe

SET MAKE=make.exe
FOR %%i IN (%LIST%) DO (
	IF EXIST %%i SET MAKE=%%i&& GOTO BREAK
)
:BREAK

:: If no `make' tool is found, the default command is `make.exe'
:: Note that specifying `make' only will call this Make.bat recursively.

%MAKE% %*
IF NOT ERRORLEVEL 1 ECHO [Done]
PAUSE
