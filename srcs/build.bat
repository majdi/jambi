@echo off

if exist Jambi.obj del Jambi.obj
if exist Jambi.exe del Jambi.exe

\masm32\bin\ml /c /Cp /coff Jambi.asm
\masm32\bin\link /SUBSYSTEM:WINDOWS Jambi.obj

pause
