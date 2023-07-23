@echo off

setlocal enabledelayedexpansion

title Rime package installer - stupid_pinyin deploy tool

set root_dir=%~dp0
set PATH=%root_dir%;%PATH%

if not defined rime_dir set rime_dir=%APPDATA%\Rime
if not defined download_cache_dir set download_cache_dir=%TEMP%

echo.
echo Rime package installer - stupid_pinyin deploy tool
echo.
echo Working directory: %CD%
echo Package installer directory: %root_dir%
echo Rime user directory: %rime_dir%
echo.

if defined ProgramFiles(x86) (set arch=64) else (set arch=32)

call :find_7z

if not defined use_plum if "%has_git_bash%" == "1" set use_plum=1

:process_arguments
if "%1" == "" set batch_interactive=1

if "%1" == "--select" if "%use_plum" == "1" (
  call :install_with_plum %*
  exit /b !errorlevel!
)

set /a installed_packages=0

:next
if "%batch_interactive%" == "1" (
  set package=stupid_pinyin.zip
) else (
  set package=%1
  shift
)
if "%package%" == "" goto finish

call :install_package
if errorlevel 1 exit /b %errorlevel%
goto next

:install_package
if "%package%" == "7z" (
  call :install_7z
  exit /b %errorlevel%
) else if "%package:.zip=%.zip" == "%package%" (
  if "https://github.com/%package:https://github.com/=%" == "%package%" (
     set user_repo_path=%package:https://github.com/=%
     set package_repo=%user_repo_path:/archive/master.zip=%
     call :download_package
  ) else (
    set package_file=%package%
    call :install_zip_package
  )
  goto :after_install_package
)

:after_install_package
if not errorlevel 1 set /a installed_packages+=1
exit /b %errorlevel%

:install_zip_package
call :install_7z /needed
if errorlevel 1 exit /b %errorlevel%
echo.
echo Unpacking %package_file% ...
echo.
for %%f in (%package_file%) do set package_dir=%%~nf
set unpack_package_dir=%TEMP%\%package_dir%
rem clean up obsolete files in target directory
if exist "%unpack_package_dir%" rmdir /s /q "%unpack_package_dir%"
rem unzip package
7z x "%package_file%" -o"%TEMP%" -y
if errorlevel 1 (
  set error_message=Error unpacking package %package_file%
  goto error
)
if not exist "%rime_dir%" (
  mkdir "%rime_dir%"
  if errorlevel 1 (
    set error_message=Error creating rime user directory: %rime_dir%
    goto error
  )
)
rem install files from the unzipped package
pushd "%unpack_package_dir%"
for %%f in (
    *.yaml
    *.txt
    opencc\*.json
    opencc\*.ocd
    opencc\*.txt
) do (
  echo.
  echo Installing %%f ...
  echo.
  set target_file=%rime_dir%\%%f
  for %%t in (!target_file!) do set target_dir=%%~dpt
  if not exist "!target_dir!" mkdir "!target_dir!"
  copy /y "%%f" "!target_file!"
  if errorlevel 1 (
    popd
    set error_message=Error installing files from package %package%
    goto error
  )
)
popd
goto :finish
exit /b

:install_package_group
if not defined package_list (
  set error_message=package_list is undefined in %package%
  goto error
)
for %%p in (%package_list%) do (
  set package=%%p
  call :install_package
  if errorlevel 1 exit /b !errorlevel!
)
exit /b

:install_7z
where /q 7z
if not errorlevel 1 (
   if "%1" == "/needed" exit /b
   echo.
   echo Found 7z
   echo.
   exit /b
)

rem check for updates at https://www.7-zip.org/download.html
if not defined _7z_version set _7z_version=18.01

if "%arch%" == "64" (set _7z_arch=-x%arch%) else (set _7z_arch=)
set _7z_installer=7z%_7z_version:.=%%_7z_arch%.exe

rem find local 7z installer
where /q %_7z_installer%
if not errorlevel 1 (
   echo.
   echo Found installer: %_7z_installer%
   echo.
   set _7z_installer_path=%_7z_installer%
   goto run_7z_installer
)

set _7z_installer_path=%download_cache_dir%\%_7z_installer%
if "%no_update%" == "1" if exist "%_7z_installer_path%" goto run_7z_installer

:download_7z_installer
set _7z_download_url=https://www.7-zip.org/a/%_7z_installer%
if not defined downloader (
   echo.
   echo TODO: please download and install 7z: %_7z_download_url%
   echo.
   set error_message=Downloader not found.
   goto error
)
echo.
echo Downloading installer: %_7z_installer%
echo.
%downloader% "%_7z_download_url%" %save_to% "%_7z_installer_path%"
if errorlevel 1 (
  set error_message=Error downloading %_7z_installer%
  goto error
)
rem TODO: verify installer
echo.
echo Download complete: %_7z_installer%
echo.

:run_7z_installer
echo.
echo Installing 7z ...
echo.
"%_7z_installer_path%" /S
exit /b

:find_7z
set search_path=^
%ProgramFiles%\7-Zip;

if defined ProgramW6432 set search_path=%search_path%^
%ProgramW6432%\7-Zip;

if defined ProgramFiles(x86) set search_path=%search_path%^
%ProgramFiles(x86)%\7-Zip;

set PATH=%search_path%%PATH%

where /q 7z
if %errorlevel% equ 0 set has_7z=1
exit /b

:error
echo.
echo Installation failed: %error_message%
echo.
exit /b 1

:finish
echo.
if %installed_packages% equ 0 (
  echo No package installed.
) else (
  echo Installed %installed_packages% packages.
  exit
)
