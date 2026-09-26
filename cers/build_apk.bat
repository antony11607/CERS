@echo off
cd /d "d:\Antony\projects\Flutter app\CERS\cers"
echo Current dir: %cd%
"C:\flutter\bin\flutter.bat" pub get
"C:\flutter\bin\flutter.bat" build apk --debug
echo Build exit code: %ERRORLEVEL%
pause