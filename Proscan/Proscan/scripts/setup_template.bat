@echo off
echo ========================================
echo ThyScan DOCX Template Setup
echo ========================================
echo.

REM Check if Node.js is available
where node >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo [1/3] Node.js found!
    echo [2/3] Installing docx package...
    call npm install docx
    if %ERRORLEVEL% EQU 0 (
        echo [3/3] Creating template...
        node create_template.js
        if %ERRORLEVEL% EQU 0 (
            echo.
            echo ========================================
            echo SUCCESS! Template created.
            echo ========================================
            echo.
            echo You can now run: flutter run
            pause
            exit /b 0
        )
    )
)

REM Check if Python is available
where python >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo [1/3] Python found!
    echo [2/3] Installing python-docx...
    pip install python-docx
    if %ERRORLEVEL% EQU 0 (
        echo [3/3] Creating template...
        python create_docx_template.py
        if %ERRORLEVEL% EQU 0 (
            echo.
            echo ========================================
            echo SUCCESS! Template created.
            echo ========================================
            echo.
            echo You can now run: flutter run
            pause
            exit /b 0
        )
    )
)

echo.
echo ========================================
echo ERROR: Neither Node.js nor Python found
echo ========================================
echo.
echo Please install one of the following:
echo   - Node.js: https://nodejs.org/
echo   - Python: https://www.python.org/
echo.
echo Or create the template manually in Microsoft Word.
echo See: assets/docx/README.md for instructions.
echo.
pause
exit /b 1
