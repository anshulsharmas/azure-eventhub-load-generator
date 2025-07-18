@echo off
REM Windows batch script to set up and run the Azure Event Hub Simulator

echo Azure Event Hub Simulator - Windows Setup
echo ==========================================

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo Error: Python is not installed or not in PATH
    echo Please install Python 3.7+ and try again
    pause
    exit /b 1
)

echo Python found. Installing dependencies...

REM Install requirements
python -m pip install -r requirements.txt
if errorlevel 1 (
    echo Error: Failed to install requirements
    pause
    exit /b 1
)

echo.
echo Dependencies installed successfully!
echo.

REM Check environment variables
if "%EVENT_HUB_CONNECTION_STRING%"=="" (
    echo Warning: EVENT_HUB_CONNECTION_STRING environment variable is not set
    echo Please set this variable before running the simulator
    echo.
)

if "%EVENT_HUB_NAME%"=="" (
    echo Warning: EVENT_HUB_NAME environment variable is not set
    echo Please set this variable before running the simulator
    echo.
)

echo Setup complete! 
echo.
echo To run the simulator:
echo   python eventhub_simulator.py --help
echo.
echo To run performance tests:
echo   python performance_test.py
echo.
pause
