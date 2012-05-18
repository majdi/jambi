.386
.model flat, stdcall

	include	\masm32\include\windows.inc
	include	\masm32\include\kernel32.inc
	include	\masm32\include\user32.inc

	includelib	\masm32\lib\kernel32.lib
	includelib	\masm32\lib\user32.lib

.data

.code

start:
	push	0
	call	ExitProcess
	
end	start
