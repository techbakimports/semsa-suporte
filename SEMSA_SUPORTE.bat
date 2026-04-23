@echo off
powershell -Command "Start-Process powershell -Verb RunAs -ArgumentList '-ExecutionPolicy Bypass -NoExit -Command \"irm https://raw.githubusercontent.com/techbakimports/semsa-suporte/refs/heads/main/suporte.ps1 | iex\"'"
