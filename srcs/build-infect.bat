@echo off

if exist infect.obj del infect.obj
if exist infect.exe del infect.exe

\masm32\bin\ml /c /Cp /coff infect.asm
\masm32\bin\link /SUBSYSTEM:WINDOWS infect.obj

pause
