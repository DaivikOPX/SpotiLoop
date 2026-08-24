@echo off
title Push SpotiLoop to GitHub
cd /d "D:\Spotify-AB-Looper"
echo ========================================================
echo   Pushing SpotiLoop Pro to https://github.com/DaivikOPX/SpotiLoop
echo ========================================================
echo.
echo If a GitHub browser login window appears, please click "Sign in with your browser".
echo.
git push -u origin main
echo.
echo ========================================================
echo   Done! Check your repository at:
echo   https://github.com/DaivikOPX/SpotiLoop
echo ========================================================
pause
