@echo OFF
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Copyright (C) 2017-2019 miniencodes.nl                                                                                           :::
::                                                                                                                                  :::
:: Author: Shinchiro                                                                                                                :::
::                                                                                                                                  :::
:: Purpose: To re-encode anime to small size with little effort, without GUI.                                                       :::
:: WARNING: DON'T PUT THIS SCRIPT IN SAME FOLDER AS INPUT FILE, IT WILL OVERWRITE THE INPUT FILE.                                   :::
:: The lock file is needed to force only one encoding at same time. Delete this file after you interrupt/abort encoding process.    :::
:: You can create symlink (mklink) for eac3to since it contains a lot of dependencies.                                              :::
:: This script is NOT suitable to be run on SSD since it has chance to wear out it faster.                                          :::
:: Support encode queuing.                                                                                                          :::
:: Put avs4x26x, x265, ffmpeg, opusenc, mkvmerge in tooldir. See the end of file to see how these files organized.                  :::
::                                                                                                                                  :::
:: Avisynth+ need to installed. Link -> https://github.com/pinterf/AviSynthPlus/releases                                            :::
:: Since Avisynth+ support 64 bit, make sure ffmpeg and plugins has same bit. Example 64-bit of ffms.dll and ffmpeg                 :::
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
set tooldir=D:\EncoderToolsFolder
::
set avs4x26x="%tooldir%\avs4x26x.exe"
set x265="%tooldir%\x265.exe"
set x264="%tooldir%\x264.exe"
set ffmpeg="%tooldir%\ffmpeg.exe"
set opusenc="%tooldir%\opusenc.exe"
set mkvmerge="%tooldir%\mkvmerge.exe"
set lockfile="%tooldir%\lock"
set eac3to="%tooldir%\eac3to\eac3to.exe"
::
:: General encoding setting.
::
set x265_param= --crf 24 --preset medium
set x264_param= --crf 23 --preset slower --tune film
::
set opusenc_param= --vbr --bitrate 64
::

:::::::::::::::::::
:: Main Call    :::
:::::::::::::::::::
for %%A in (%*) do (
    title Encoding "%%~nxA"
    call :Wait
    call :SetTempEncodeDir %%A
    ::call :WriteAVS %%A
    call :EncodeAudio_opus %%A
    call :EncodeVideo_x265 %%A
    ::call :EncodeVideo_x264 %%A
    ::call :EncodeVideoHardsub %%A
    ::call :ExtractTimecode %%A
    call :Mux %%A
    ::call :EncodeAllWithFFmpeg %%A
    call :DoNothing
)
:: Uncomment line below to shutdown after finish encoding.
::call :Shutdown
@pause
goto :EOF

:::::::::::::::::::::::
:SetTempEncodeDir   :::
:::::::::::::::::::::::
mkdir "%~dp0\__temp__"
set tempdir=%~dp0\__temp__
set encodedir=%~dp0
goto :EOF

:::::::::::::::
:WriteAVS   :::
:::::::::::::::
:: Disabled/commented by default since we feed encoder with y4m via ffmpeg
:: echo LoadPlugin("%tooldir%\ffms2.dll") >> "%tempdir%\%~n1.avs"
:: echo ffvideosource("%~f1", cachefile="%tempdir%\%~n1.ffindex", colorspace="YUV420P10") >> "%tempdir%\%~n1.avs"
echo LoadPlugin("D:\Installer\Encoder\Avisynth\aWarpSharp.dll") >> "%tempdir%\%~n1.avs"
echo LoadPlugin("D:\Installer\Encoder\Avisynth\ffms2.dll") >> "%tempdir%\%~n1.avs"
echo LoadPlugin("D:\Installer\Encoder\Avisynth\debilinear.dll") >> "%tempdir%\%~n1.avs"
echo ffvideosource("%~f1", cachefile="%tempdir%\%~n1.ffindex") >> "%tempdir%\%~n1.avs"
goto :EOF

:::::::::::::::::::::::
:ExtractTimecode    :::
:::::::::::::::::::::::
:: Only useful if we dealing with vfr, so disable/comment this call
%ffmpeg% -hide_banner -loglevel warning -stats -i "%~f1" -map 0:v:0 -f mkvtimestamp_v2 -c copy "%tempdir%\video_timecode.txt"
goto :EOF

:::::::::::::::::::::::
:EncodeVideo_x265   :::
:::::::::::::::::::::::
:: If the input is 10bit, create 10bit y4m pipe. Example: -pix_fmt yuv420p10
:: If the source is vfr, force with certain framerate before '-i': -r 23.976
:: For downscaling video with ffmpeg, put '-vf scale=-1:360:flags=spline' after "%~f1. To sharpen downscaled, add unsharp=2.5:2.5:1.5"
::
:: If we want to feed avs file directly to ffmpeg, replace input file with avs file ("%tempdir%\%~n1.avs")
:: Or feed avs with avs4x26x:
:: "%avs4x26x%" --x26x-binary %x265% %x265_param% --output "%tempdir%\%~n1.hevc" "%tempdir%\%~n1.avs"

%ffmpeg% -hide_banner -loglevel warning -stats -i "%~f1" -map 0:v:0 -f yuv4mpegpipe -strict -1 -pix_fmt yuv420p - | %x265% --y4m %x265_param% --output "%tempdir%\%~n1.hevc" -
goto :EOF

:::::::::::::::::::::::
:EncodeVideo_x264   :::
:::::::::::::::::::::::
%ffmpeg% -hide_banner -loglevel warning -stats -i "%~f1" -map 0:v:0 -f yuv4mpegpipe -pix_fmt yuv420p - | %x264% --demuxer y4m %x264_param% --output "%tempdir%\%~n1.h264" -
goto :EOF

:::::::::::::::::::::::
:EncodeVideoHardsub :::
:::::::::::::::::::::::
:: This call will demonstrate how to hardsub subtitle with ffmpeg. FFmpeg need to be compiled with '--enable-libass'.
:: If you used this call, the batch script need to be run as administrator since 'mklink' required administrator privilege.
mklink "%tempdir%\video.mkv" "%~f1"
cd %tempdir%
:: Hardsub rendered subtitle and downscaled it to 360p.
%ffmpeg% -hide_banner -loglevel warning -stats -i "%~f1" -map 0:v:0 -f yuv4mpegpipe -vf subtitles=video.mkv,scale=-1:360:flags=spline -pix_fmt yuv420p - | %x265% --y4m %x265_param% --output "%tempdir%\%~n1.hevc" -
cd %~dp0
goto :EOF

:::::::::::::::::::::::
:EncodeAudio_opus   :::
:::::::::::::::::::::::
time /T > "%tempdir%\start_time.txt"
set /p start_time=< "%tempdir%\start_time.txt"

:: -map 0:a:0 will select first audio stream in source file
:: Encoding audio into lossless flac even the audio's format is already flac. Since, lossless -> lossless = lossless
%ffmpeg% -hide_banner -loglevel warning -stats -i "%~f1" -map 0:a:0 -f flac -compression_level 2 - | %opusenc% %opusenc_param% --ignorelength - "%tempdir%\encode.opus"

:: If the audio is multichannel & want to downmix to stereo, process it with eac3to
:: %ffmpeg% -hide_banner -loglevel warning -stats -i "%~f1" -map 0:a:0 -c:a flac -compression_level 2 "%tempdir%\raw.flac"
:: %eac3to% "%tempdir%\raw.flac" stdout.wav -downStereo | %opusenc% %opusenc_param% --ignorelength - "%tempdir%\encode.opus"
:: del "%tempdir%\raw.flac"
goto :EOF

:::::::::::
:Mux    :::
:::::::::::
time /T > "%tempdir%\end_time.txt"
set /p end_time=< "%tempdir%\end_time.txt"

:: When 'ExtractTimecode' is called/uncomment, add this before video stream: --timecodes 0:"%tempdir%\video_timecode.txt"
%mkvmerge% -o "%encodedir%\%~n1.mkv" ^
              "%tempdir%\%~n1.hevc" ^
              -T --no-chapters --no-global-tags "%tempdir%\encode.opus" ^
              -D -A -T "%~f1"

echo Finished. Start from %start_time% - %end_time%

:: Cleanup. Delete temporary folder created when encoding
if exist "%encodedir%\%~n1.mkv" (
    rmdir /S /Q "%tempdir%"
)
del %lockfile%
goto :EOF

:::::::::::::::::::::::::::
:EncodeAllWithFFmpeg    :::
:::::::::::::::::::::::::::
:: Encode video and audio with ffmpeg. 'SetTempEncodeDir', 'EncodeAudio', 'EncodeVideo', 'Mux' calls must be disabled/comment.
:: This will tell ffmpeg to use & copy all streams from input file except for video and audio.
%ffmpeg% -hide_banner -i "%~f1" -map 0 -c copy ^
                          -c:v libx265 -pix_fmt yuv420p -preset medium -x265-params crf=24:rc-lookahead=60:qcomp=0.70:aq-strength=1 ^
                          -c:a libopus -b:a 64k ^
                          "%~dp0\%~n1.mkv"

del %lockfile%
goto :EOF

:::::::::::
:Wait   :::
:::::::::::
if exist %lockfile% (
    timeout /t 100 /nobreak
)
if not exist %lockfile% (
    type NUL > %lockfile%
) else (
    call :Wait
)
goto :EOF

:::::::::::::::
:Shutdown   :::
:::::::::::::::
ping 127.0.0.1 -n 5 > nul
if exist %lockfile% (
    echo Another encoding process is running. Shutdown is not triggered.
    goto :EOF
)
echo.
echo.
echo.
echo.
echo.
echo Shutdown in next 30 seconds. Press Ctrl+C or close to abort.
timeout /t 30
shutdown /t 0 /s
goto :EOF

:::::::::::::::
:DoNothing  :::
:::::::::::::::
goto :EOF

:::::::::::::::::::::::::::
:: Folder Structure     :::
:::::::::::::::::::::::::::
::
::/d/EncoderToolsFolder
::├── eac3to -> /d/Encoder/eac3to (folder, symlink)
::├── avs4x26x.exe
::├── ffmpeg.exe
::├── lock (autogenerated)
::├── mkvmerge.exe
::├── opusenc.exe
::├── x264.exe
::└── x265.exe
::
