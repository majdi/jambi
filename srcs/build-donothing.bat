@echo off

if exist donothing.obj del donothing.obj
if exist donothing.exe del donothing.exe

\masm32\bin\ml /c /Cp /coff donothing.asm
\masm32\bin\link /SUBSYSTEM:WINDOWS donothing.obj

pause
