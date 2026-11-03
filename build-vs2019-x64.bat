@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "BUILD_DIR=%SCRIPT_DIR%build_vs2019_x64"
set "STAGE_DIR=%BUILD_DIR%\install"
for %%I in ("%SCRIPT_DIR%..\..\Tiny3D\dependencies\sdl2") do set "TARGET_DIR=%%~fI"
set "TARGET_INC_DIR=%TARGET_DIR%\include\SDL2"
set "TARGET_BIN_DIR=%TARGET_DIR%\prebuilt\windows\x64\bin"
set "TARGET_LIB_DIR=%TARGET_DIR%\prebuilt\windows\x64\lib"
set "BRIDGE_BACKUP=%BUILD_DIR%\SDL_config_bridge.h.bak"

echo ============================================================================
echo [0/4] Cleaning previous build artifacts...
echo ============================================================================
if exist "%BUILD_DIR%" (
    rmdir /S /Q "%BUILD_DIR%"
    if exist "%BUILD_DIR%" (
        echo [ERROR] Failed to clean "%BUILD_DIR%". Please close any open files/IDE and retry.
        goto :error
    )
)
if exist "%TARGET_BIN_DIR%\SDL2.dll" del /F /Q "%TARGET_BIN_DIR%\SDL2.dll"
if exist "%TARGET_LIB_DIR%\SDL2.lib" del /F /Q "%TARGET_LIB_DIR%\SDL2.lib"
if exist "%TARGET_LIB_DIR%\SDL2main.lib" del /F /Q "%TARGET_LIB_DIR%\SDL2main.lib"

echo.
echo ============================================================================
echo [1/4] Configuring SDL2 with CMake (Visual Studio 16 2019, x64, Release)...
echo ============================================================================
cmake -S "%SCRIPT_DIR%." -B "%BUILD_DIR%" ^
    -G "Visual Studio 16 2019" ^
    -A x64 ^
    -DSDL_SHARED=ON ^
    -DSDL_STATIC=OFF ^
    -DSDL_TEST=OFF ^
    -DSDL_TESTS=OFF
if errorlevel 1 (
    echo [ERROR] CMake configure failed!
    goto :error
)

echo.
echo ============================================================================
echo [2/4] Building SDL2 (Release)...
echo ============================================================================
cmake --build "%BUILD_DIR%" --config Release
if errorlevel 1 (
    echo [ERROR] CMake build failed!
    goto :error
)

echo.
echo ============================================================================
echo [3/4] Staging CMake install to "%STAGE_DIR%"...
echo ============================================================================
if exist "%STAGE_DIR%" rmdir /S /Q "%STAGE_DIR%"
cmake --install "%BUILD_DIR%" --config Release --prefix "%STAGE_DIR%"
if errorlevel 1 (
    echo [ERROR] CMake install failed!
    goto :error
)

echo.
echo ============================================================================
echo [4/4] Deploying headers and binaries to "%TARGET_DIR%"...
echo ============================================================================
if not exist "%TARGET_INC_DIR%" mkdir "%TARGET_INC_DIR%"
if not exist "%TARGET_BIN_DIR%" mkdir "%TARGET_BIN_DIR%"
if not exist "%TARGET_LIB_DIR%" mkdir "%TARGET_LIB_DIR%"

:: Backup existing platform-bridge SDL_config.h so it won't be overwritten
if exist "%TARGET_INC_DIR%\SDL_config.h" (
    copy /Y "%TARGET_INC_DIR%\SDL_config.h" "%BRIDGE_BACKUP%" >nul
)

:: Copy all headers from staged install (including SDL_revision.h)
xcopy /Y /Q "%STAGE_DIR%\include\SDL2\*.h" "%TARGET_INC_DIR%\" >nul
if errorlevel 1 (
    echo [ERROR] Failed to copy header files!
    goto :error
)

:: Save the CMake-generated Windows SDL_config.h as SDL_config_windows.h
copy /Y "%STAGE_DIR%\include\SDL2\SDL_config.h" "%TARGET_INC_DIR%\SDL_config_windows.h" >nul
if errorlevel 1 (
    echo [ERROR] Failed to update SDL_config_windows.h!
    goto :error
)

:: Restore the platform-bridge SDL_config.h
if exist "%BRIDGE_BACKUP%" (
    copy /Y "%BRIDGE_BACKUP%" "%TARGET_INC_DIR%\SDL_config.h" >nul
    del /Q "%BRIDGE_BACKUP%" >nul
)

:: Copy runtime DLL and import/main libraries
copy /Y "%STAGE_DIR%\bin\SDL2.dll"     "%TARGET_BIN_DIR%\SDL2.dll" >nul
if errorlevel 1 goto :copy_lib_error

copy /Y "%STAGE_DIR%\lib\SDL2.lib"     "%TARGET_LIB_DIR%\SDL2.lib" >nul
if errorlevel 1 goto :copy_lib_error

copy /Y "%STAGE_DIR%\lib\SDL2main.lib" "%TARGET_LIB_DIR%\SDL2main.lib" >nul
if errorlevel 1 goto :copy_lib_error

echo.
echo ============================================================================
echo [SUCCESS] SDL2 Windows x64 Release build and deployment completed!
echo   Headers : %TARGET_INC_DIR%
echo   Config  : %TARGET_INC_DIR%\SDL_config_windows.h (bridge SDL_config.h preserved)
echo   DLL     : %TARGET_BIN_DIR%\SDL2.dll
echo   LIB     : %TARGET_LIB_DIR%\SDL2.lib, SDL2main.lib
echo ============================================================================
endlocal
pause
exit /b 0

:copy_lib_error
echo [ERROR] Failed to copy binary/library files!

:error
endlocal
pause
exit /b 1
