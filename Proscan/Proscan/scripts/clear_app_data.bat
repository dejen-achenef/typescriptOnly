@echo off
echo ========================================
echo Clearing ThyScan App Data
echo ========================================
echo.

echo Stopping Flutter app...
taskkill /F /IM flutter.exe 2>nul

echo.
echo Clearing app data on Android device...
adb shell pm clear com.example.thyscan

echo.
echo ========================================
echo Done! App data cleared.
echo ========================================
echo.
echo You can now run: flutter run
echo.
pause
