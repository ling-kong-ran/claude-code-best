@echo off
chcp 65001 >nul
bun build src/entrypoints/cli.tsx --compile --outfile ccb.exe
pause
