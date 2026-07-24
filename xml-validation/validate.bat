@echo off
setlocal

set PYTHON_EXE=%~dp0python\python.exe
set GET_PIP=%~dp0resources\get-pip.py

goto :COMMENT_END

:COMMENT_START
echo ======================================
echo Checking Python
echo ======================================

if not exist "%PYTHON_EXE%" (
    echo Python not found:
    echo %PYTHON_EXE%
    goto ERROR
)

"%PYTHON_EXE%" --version

echo.
echo ======================================
echo Checking pip
echo ======================================

"%PYTHON_EXE%" -m pip --version >nul 2>&1

if errorlevel 1 (
    echo pip not found.

    if not exist "%GET_PIP%" (
        echo get-pip.py not found:
        echo %GET_PIP%
        goto ERROR
    )

    echo Installing pip...
    "%PYTHON_EXE%" "%GET_PIP%"

    if errorlevel 1 (
        echo Failed to install pip.
        goto ERROR
    )
)

echo.
echo ======================================
echo Upgrading pip
echo ======================================

"%PYTHON_EXE%" -m pip install --upgrade pip

if errorlevel 1 (
    echo Failed to upgrade pip.
    goto ERROR
)

echo.
echo ======================================
echo Installing requirements
echo ======================================

"%PYTHON_EXE%" -m pip install -r "%~dp0resources\requirements.txt"

if errorlevel 1 (
    echo Failed to install requirements.
    goto ERROR
)

:COMMENT_END

echo.
echo ======================================
echo Running validate.py
echo ======================================

"%PYTHON_EXE%" "%~dp0script\validate.py"

if errorlevel 1 (
    echo validate.py failed.
    goto ERROR
)

echo.
echo ======================================
echo SUCCESS
echo ======================================
echo Validation completed successfully.

goto END

:ERROR
echo.
echo ======================================
echo ERROR
echo ======================================
echo Error Code: %ERRORLEVEL%

:END
echo.
echo Press any key to close...
pause >nul