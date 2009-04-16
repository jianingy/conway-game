;=================================================================
;    The Game of Life, a Cell model by J.H Conway 1970
;
;    Written by Jianing Yang
;
;=================================================================
.386
.model flat, stdcall
option casemap:none

;Import .INC files
include windows.inc
include kernel32.inc
include user32.inc
include gdi32.inc
include comctl32.inc
include shlwapi.inc
include shell32.inc
include comdlg32.inc

;Import .LIB files
includelib user32.lib
includelib kernel32.lib
includelib gdi32.lib
includelib comctl32.lib
includelib shlwapi.lib
includelib comdlg32.lib
includelib shell32.lib

WinMain proto :DWORD, :DWORD, :DWORD, :DWORD

.CONST
bSquare equ 8
bSize equ 80
btnLength equ 24
btnLeft equ (bSize * Square - btnLength) / 2
lInterval equ 6

IDC_START equ 1
IDC_STOP equ 2
IDC_STEP equ 3
IDC_CLEAR equ 4
IDC_INTERVAL equ 5
IDC_STATIC equ 6
idTimer1 dd 1

MainMenu  equ 1
IDM_FILE   equ 100
IDM_OPEN equ 101
IDM_SAVE equ 102
IDM_EXIT equ 103
IDM_NEW   equ 105
IDM_ABOUT equ 200

.DATA
szClassName db 'LifeGame',0
szAppName db 'The Game of Life v1.5 (Written by Jianing Yang, using MASM32)',0
szMenuName db 'MainMenu',0
szFilter db 'Life pattern files(*.lpf)',0,'*.lpf',0,0
szFileExt db 'lpf'
szOrgInterval db '25'
wLife dw 0
bLifeTop dd 0
bDeadTop dd 0
LButtonDown BOOLEAN FALSE
RButtonDown BOOLEAN FALSE
bOpByte dw 0

bInterval db lInterval dup(0)
lFilename equ 270
szFilename db lFilename dup(0)


bMatrix dd 0
bDead dd 0
bLife dd 0

.DATA?
hInstance HINSTANCE ?
szCommandLine LPSTR ?
hbrLife HBRUSH ?
hbrSpace HBRUSH ?
hpeNone HPEN ?
hpeNormal HPEN ?
hftButton HFONT ?
hDC HDC ?
hWnd HWND ?
hMenu HMENU ?


dwTimerId1 dd ?
; Macros
RGB Macro red,green,blue 
        xor eax, eax 
        mov ah, blue 
        shl eax, 8 
        mov ah, green 
        mov al, red 
EndM 

.CODE
Start:

; Get Module Handle
invoke GetModuleHandle, NULL
mov hInstance, eax

invoke GetCommandLine
mov szCommandLine, eax

invoke WinMain, hInstance, NULL, szCommandLine, SW_SHOWDEFAULT

invoke ExitProcess, eax

WinMain Proc hInst: HINSTANCE, hPrevInst: HINSTANCE, szCmdLine: LPSTR, nShowCmd: DWORD 
	LOCAL wcex: WNDCLASSEX
	LOCAL msg:MSG
	LOCAL rect:RECT
	
 	mov   wcex.cbSize,SIZEOF WNDCLASSEX
	mov   wcex.style, CS_HREDRAW or CS_VREDRAW 
 	mov   wcex.lpfnWndProc, OFFSET WndProc 
	mov   wcex.cbClsExtra, NULL 
	mov   wcex.cbWndExtra, NULL 
	push  hInstance 
	pop   wcex.hInstance 
	mov   wcex.hbrBackground, COLOR_WINDOW  
	mov   wcex.lpszMenuName, OFFSET szMenuName
	mov   wcex.lpszClassName, OFFSET szClassName 
	invoke LoadIcon, NULL, IDI_APPLICATION 
	mov   wcex.hIcon, eax 
	mov   wcex.hIconSm, eax 
	invoke LoadCursor, NULL, IDC_ARROW 
	mov   wcex.hCursor, eax 
	invoke RegisterClassEx, addr wcex

	invoke LoadMenu, hInst, MainMenu
	mov hMenu, eax
	
	mov rect.left, 0
	mov rect.top, 0
	mov rect.right, bSquare * bSize
	mov rect.bottom, bSquare * bSize
	invoke AdjustWindowRectEx, ADDR rect,\
		WS_CAPTION or WS_SYSMENU or WS_BORDER or WS_MINIMIZEBOX, TRUE, 0
	mov eax, rect.right
	mov edx, rect.bottom
	sub eax, rect.left
	sub edx, rect.top
	add eax, 128
	inc edx
	
	invoke CreateWindowEx, NULL,\ 
                ADDR szClassName,\ 
                ADDR szAppName,\ 
                WS_CAPTION or WS_SYSMENU or WS_BORDER or WS_MINIMIZEBOX,\ 
                CW_USEDEFAULT,\ 
                CW_USEDEFAULT,\ 
                eax,\ 
                edx ,\ 
                NULL,\ 
                hMenu,\ 
                hInst,\ 
                NULL 
	mov   hWnd, eax 
		
	invoke ShowWindow, hWnd, nShowCmd
	invoke UpdateWindow, hWnd

	.WHILE TRUE
                invoke GetMessage, ADDR msg,NULL,0,0 
                .BREAK .IF (!eax) 
                invoke TranslateMessage, ADDR msg 
                invoke DispatchMessage, ADDR msg 
	.ENDW 
	mov     eax,msg.wParam 

	RET
WinMain EndP
InitMatrix Proc

	invoke GetProcessHeap
	invoke HeapAlloc, eax, HEAP_ZERO_MEMORY , bSize * bSize
	mov bMatrix, eax

	invoke GetProcessHeap
	invoke HeapAlloc, eax, HEAP_ZERO_MEMORY , bSize * bSize * 4
	mov bLife, eax

	invoke GetProcessHeap
	invoke HeapAlloc, eax, HEAP_ZERO_MEMORY , bSize * bSize * 4
	mov bDead, eax

	RET
InitMatrix EndP

OnCreate Proc
LOCAL icc:INITCOMMONCONTROLSEX
.DATA
	ButtonClassName db 'Button',0
	EditClassName db 'Edit', 0
	StaticClassName db 'Static', 0
	szBtnStep db 'Step Over',0
	szBtnStart db 'Start', 0
	szBtnStop db 'Stop', 0
	szBtnClear db 'Clear',0
	szStaLabel db 'Generation Interval', 0
.DATA?
	hBtnStep HWND ?	
	hBtnStart HWND ?	
	hBtnStop HWND ?	
	hBtnClear HWND ?
	hEdtInterval HWND ?
	hLabel HWND ?
.CODE

;Initialize Data	
	RGB 255,0,0 
	invoke CreateSolidBrush, eax
	mov hbrLife, eax
	RGB 0ffh,0ffh,0ffh
	invoke CreateSolidBrush, eax
	mov hbrSpace, eax
	RGB 0ffh,0ffh,0ffh
	invoke CreatePen, PS_NULL,0, eax
	mov hpeNone, eax
	RGB 000h,000h,000h
	invoke CreatePen, PS_SOLID,1, eax
	mov hpeNormal, eax
	
	invoke InitMatrix
	
; allow drag-drop
	invoke DragAcceptFiles, hWnd, TRUE
		
;Initialize Control
	mov icc.dwSize, sizeof INITCOMMONCONTROLSEX
	mov icc.dwICC, ICC_COOL_CLASSES
	invoke InitCommonControlsEx, addr icc 
;Step Button
       invoke CreateWindowEx,NULL, ADDR ButtonClassName,ADDR szBtnStep,\ 
                WS_CHILD or WS_VISIBLE or BS_FLAT,\ 
                bSize * bSquare + 20 , bSize * bSquare - 30 , 90, 25, hWnd,IDC_STEP , hInstance, NULL 
	mov hBtnStep, eax	

;Stop Button
       invoke CreateWindowEx,NULL, ADDR ButtonClassName,ADDR szBtnStop,\ 
                WS_CHILD or WS_VISIBLE or BS_FLAT,\ 
                bSize * bSquare + 20 , bSize * bSquare - 70 , 90, 25, hWnd,IDC_STOP , hInstance, NULL 
	mov hBtnStop, eax	

;Start Button
       invoke CreateWindowEx,NULL, ADDR ButtonClassName,ADDR szBtnStart,\ 
                WS_CHILD or WS_VISIBLE or BS_FLAT,\ 
                bSize * bSquare + 20 , bSize * bSquare - 110 , 90, 25, hWnd,IDC_START , hInstance, NULL 
	mov hBtnStart, eax	

;Clear Button
       invoke CreateWindowEx,NULL, ADDR ButtonClassName,ADDR szBtnClear,\ 
                WS_CHILD or WS_VISIBLE or BS_FLAT,\ 
                bSize * bSquare + 20 , bSize * bSquare - 150 , 90, 25, hWnd,IDC_CLEAR , hInstance, NULL 
	mov hBtnStart, eax	

;Interval EditBox
       invoke CreateWindowEx,NULL, ADDR EditClassName, ADDR szOrgInterval,\ 
                WS_CHILD or WS_VISIBLE or ES_RIGHT  or WS_BORDER,\ 
                bSize * bSquare + 20 , bSize * bSquare - 190 , 90, 25, hWnd,IDC_INTERVAL , hInstance, NULL 
	mov hEdtInterval, eax	
	
;Description
       invoke CreateWindowEx,NULL, ADDR StaticClassName, ADDR szStaLabel,\ 
                WS_CHILD or WS_VISIBLE or ES_CENTER,\ 
                bSize * bSquare + 20 , bSize * bSquare - 240 , 90, 35, hWnd,IDC_STATIC , hInstance, NULL 
	mov hLabel, eax	

	RET
OnCreate EndP

DrawLife Proc
; Draw Lifes
	PUSH ebx
	invoke SelectObject, hDC, hpeNone
	mov ebx, bMatrix ;ebx = base addr of bMatrix
	xor esi,esi
	.WHILE esi < bSize
		xor edi, edi
		.WHILE edi < bSize
		
			imul eax, esi, bSize       
			add eax, edi                ; eax = ebx + esi * bSize + edi
			add eax, ebx
			
			cmp byte ptr [eax], 1
			jne next_life
			imul eax, esi, bSquare   ;eax = y
			imul edx, edi, bSquare   ;edx = x
			
			push esi
			push edi
			mov esi, eax 
			mov edi, edx
			add esi, bSquare + 1        ; esi = y + bSquare
			add edi, bSquare + 1        ; edi = x + bSquare
			inc edx
			inc eax
			invoke Rectangle,hDC, edx, eax, edi, esi
			pop edi
			pop esi
next_life:			
			inc edi
		.ENDW
		inc esi
	.ENDW
	POP ebx
	RET
DrawLife EndP


Generate Proc
	PUSH ebx
;    Generate new life
	invoke SelectObject, hDC, hpeNone
	invoke SelectObject, hDC, hbrLife
	mov ebx,  bMatrix
	mov eax, bLife
	
	mov ecx, bLifeTop
	
	JMP IF_LIFE
NEXT_LIFE:	
		mov edx,  dword ptr [eax + ecx * 4]
		mov edi, edx
		shr edi, 16
		movzx esi, dx
		
		push eax
		push ecx
		push ebx		
		
		imul eax, esi, bSize
		add eax, edi
		add eax, ebx
		mov byte ptr [eax], 1
; Draw a life
		imul esi, bSquare
		mov eax, esi
		add eax, bSquare + 1 
		imul edi, bSquare
		mov edx, edi
		add edx, bSquare + 1 
		inc edi
		inc esi
		invoke Rectangle, hDC, edi, esi, edx,eax		
		
		pop ebx
		pop ecx
		pop eax
		
		dec ecx
IF_LIFE:
		cmp ecx, 0
		JG NEXT_LIFE

;     Clear Dead life
	invoke SelectObject, hDC, hpeNormal
	invoke SelectObject, hDC, hbrSpace
	mov ebx, bMatrix
	mov eax, bDead	
	mov ecx, bDeadTop
	JMP IF_DEAD
NEXT_DEAD:	
		mov edx,  dword ptr [eax + ecx * 4]
		mov edi, edx
		shr edi, 16
		movzx esi, dx
		
		push eax
		push ecx
		push ebx
				
		imul eax, esi, bSize
		add eax, edi
		add eax, ebx
		mov byte ptr [eax], 0
;    Draw a space
		imul esi, bSquare
		mov eax, esi
		add eax, bSquare + 1
		imul edi, bSquare
		mov edx, edi
		add edi, bSquare + 1
		invoke Rectangle, hDC, edi, esi, edx,eax		

		pop ebx
		pop ecx
		pop eax
		
		dec ecx
IF_DEAD:
		cmp ecx, 0
		JG NEXT_DEAD
	
	POP ebx
	RET
Generate EndP

StepOver Proc
LOCAL pt:POINT
	PUSH ebx
;     Clear storage 
	mov ecx, bSize * bSize
	mov eax, bLife
	mov edx, bDead
Init_Queue:
	mov dword ptr [eax + ecx * 4],  0
	mov dword ptr [edx + ecx * 4],  0
	loop Init_Queue
      mov bLifeTop, 0
      mov bDeadTop, 0
		
	mov ebx, bMatrix
	xor esi, esi
	; esi = y, edi = x;
	.WHILE esi < bSize
		xor edi,edi
		.WHILE edi < bSize
			mov wLife, 0
			mov eax, -1
			JMP SO_IFAX
SO_BEGINAX:
				mov edx, -1
				JMP SO_IFDX
SO_BEGINDX:					
					; if the square is out of bound
					; esi + eax, edi + edx
					mov ecx, esi
					add ecx, eax

					CMP ecx, bSize
					JGE SO_NEXTAX
					CMP ecx, 0
					JL SO_NEXTAX

					mov ecx, edi
					add ecx, edx

					CMP ecx, bSize
					JGE SO_NEXTDX
					CMP ecx, 0
					JL SO_NEXTDX

					.IF eax == 0 && edx == 0
					    JMP SO_NEXTDX
					.ENDIF
					
					mov ecx, esi
					add ecx, eax
					imul ecx, bSize
					add ecx, edi
					add ecx, edx
					add ecx, ebx
					
					cmp byte ptr [ecx], 1
					jne SO_NEXTDX
					inc wLife
SO_NEXTDX:					
					inc edx
SO_IFDX:
				CMP edx, 1
				JLE 	SO_BEGINDX					
SO_NEXTAX:
				inc eax
SO_IFAX:
			CMP eax, 1
			JLE 	SO_BEGINAX
								
; Compute the result of one generation
			imul ecx, esi, bSize
			add ecx, edi
			add ecx, ebx
			
			mov eax, bLife
			
			PUSH ebx
			
			.IF wLife == 3 && byte ptr[ecx] == 0			
				inc bLifeTop
				mov edx, bLifeTop				
				imul edx, 4
				add edx, eax
				
				mov ebx, edi
				shl ebx, 16
				mov bx, si
				
				mov dword ptr [edx], ebx
			.ENDIF

			mov eax, bDead
			
			.IF wLife < 2 && byte ptr[ecx] == 1
				inc bDeadTop
				mov edx, bDeadTop				
				imul edx, 4
				add edx, eax
				
				mov ebx, edi
				shl ebx, 16
				mov bx, si
				
				mov dword ptr [edx], ebx
			.ENDIF
			
			.IF wLife > 3 && byte ptr[ecx] == 1
				inc bDeadTop
				mov edx, bDeadTop				
				imul edx, 4
				add edx, eax
				
				mov ebx, edi
				shl ebx, 16
				mov bx, si
				
				mov dword ptr [edx], ebx
			.ENDIF

			POP ebx
			
SO_NEXTEDI:						
			inc edi
		.ENDW
		inc esi
	.ENDW
	invoke Generate
	POP ebx
	RET
StepOver EndP

OnButtonDown Proc wParam:WPARAM, lParam:WPARAM, useBrush:HBRUSH, isLife: DWORD
	LOCAL rect:RECT
	PUSH ebx
	invoke GetDC, hWnd
	mov hDC, eax
	
	invoke SelectObject, hDC, hpeNone
	invoke SelectObject, hDC, useBrush	
	mov bl, bSquare
;     esi = y of matrix[y][x]
	mov eax, lParam
	shr eax, 16
;     detect the case that mouse is out of bound
	cmp ax, bSize * bSquare
	JGE out_bound
	cmp ax, 0
	JL out_bound
;     esi = eax / bSquare
	idiv bl
	movzx esi,al 

;     edi = x of matrix[y][x]	
	mov eax, lParam
;     detect the case that mouse is out of bound
	cmp ax, bSize * bSquare
	JGE out_bound
	cmp ax, 0
	JL out_bound
;     edi = eax / bSquare
	idiv bl
	movzx edi, al
	
;     write to array
	mov eax, bMatrix
	imul ebx, esi, bSize
	add eax, ebx
	add eax, edi
	mov cl, byte ptr isLife
	mov byte ptr[eax], cl
	
	imul esi, bSquare
	imul edi, bSquare
	
	mov eax, esi
	mov edx, edi
	add eax, bSquare + 1
	add edx, bSquare + 1
	inc esi
	inc edi
	invoke Rectangle, hDC, edi, esi, edx, eax
	POP ebx
out_bound:
	RET	
OnButtonDown EndP


OnPaint Proc
LOCAL ps: PAINTSTRUCT
LOCAL rect: RECT

	PUSH ebx
	invoke BeginPaint, hWnd, addr ps
	mov hDC, eax

	invoke SelectObject, hDC, eax
	invoke SelectObject, hDC, hbrLife
	invoke SelectObject, hDC, hpeNormal
	xor ecx, ecx
	
	.WHILE ecx <= bSize
		imul edx,  ecx, bSquare
; Draw Horizontal Lines
		push ecx
		push edx
		invoke MoveToEx, hDC, 0, edx, NULL
		invoke LineTo, hDC, bSize * bSquare, edx
		pop edx
		pop ecx
; Draw Vertical Lines		
		push ecx
		push edx
		invoke MoveToEx, hDC, edx, 0,  NULL
		invoke LineTo, hDC, edx, bSize * bSquare
		pop edx
		pop ecx

		inc ecx
	.ENDW
	
	invoke DrawLife
	invoke EndPaint, hWnd, addr ps

;-------------------------- 
; Does EndPaint close the handle of my device????
	invoke GetDC, hWnd
	mov hDC, eax
;--------------------------
	POP ebx
	RET
OnPaint EndP

OnLButtonDown Proc wParam:WPARAM, lParam:LPARAM
	mov LButtonDown, TRUE
	invoke OnButtonDown, wParam, lParam, hbrLife, 1 
	RET
OnLButtonDown EndP
OnLButtonUp Proc wParam:WPARAM, lParam:LPARAM
	mov LButtonDown, FALSE
	RET
OnLButtonUp EndP
OnRButtonDown Proc wParam:WPARAM, lParam:LPARAM
	mov RButtonDown, TRUE
	invoke OnButtonDown, wParam, lParam, hbrSpace, 0 
	RET
OnRButtonDown EndP
OnRButtonUp Proc wParam:WPARAM, lParam:LPARAM
	mov RButtonDown, FALSE
	RET
OnRButtonUp EndP
OnGameStart Proc
	invoke StepOver
	RET
OnGameStart EndP

OnMouseMove Proc wParam:WPARAM, lParam: LPARAM
	.IF LButtonDown == TRUE	
		invoke OnButtonDown, wParam, lParam, hbrLife, 1
	.ELSEIF RButtonDown == TRUE	
		invoke OnButtonDown, wParam, lParam, hbrSpace, 0
	.ENDIF
	RET
OnMouseMove EndP

OnOpenFile Proc
	LOCAL ofn:OPENFILENAME
	.DATA
		szOpenDlgTitle db 'Open life pattern from file', 0
	.DATA?
		hOpenFile HANDLE ?	
	.CODE
	invoke RtlZeroMemory, addr ofn, SIZEOF OPENFILENAME
	mov ofn.lStructSize, SIZEOF OPENFILENAME
	mov eax, hWnd
	mov ofn.hwndOwner, eax
	mov ofn.lpstrFilter, offset szFilter
	mov ofn.lpstrFileTitle, offset szFilename
	mov ofn.nMaxFileTitle, lFilename
	mov ofn.lpstrDefExt, offset  szFileExt	
	mov ofn.Flags,  OFN_PATHMUSTEXIST or OFN_HIDEREADONLY or OFN_FILEMUSTEXIST
	invoke GetOpenFileName, addr ofn
	invoke CreateFile, addr szFilename, GENERIC_READ, 0, NULL, OPEN_EXISTING\
		, FILE_ATTRIBUTE_NORMAL, NULL
	mov hOpenFile, eax
	invoke ReadFile, hOpenFile, bMatrix, bSize * bSize, addr bOpByte, NULL
	invoke CloseHandle, hOpenFile
	invoke InvalidateRect, hWnd, NULL, TRUE
	RET
OnOpenFile EndP
OnSaveFile Proc
	LOCAL ofn:OPENFILENAME
	.DATA
		szSaveDlgTitle db 'Save life pattern to file', 0
	.DATA?
		hSaveFile HANDLE ?
	.CODE
	invoke RtlZeroMemory, addr ofn, SIZEOF OPENFILENAME
	mov ofn.lStructSize, SIZEOF OPENFILENAME
	mov eax, hWnd
	mov ofn.hwndOwner, eax
	mov ofn.lpstrFilter, offset szFilter
	mov ofn.Flags,  OFN_OVERWRITEPROMPT or OFN_EXTENSIONDIFFERENT
	mov ofn.lpstrFileTitle, offset szFilename
	mov ofn.nMaxFileTitle, lFilename
	mov ofn.lpstrDefExt, offset szFileExt	
	invoke GetSaveFileName, addr ofn	
	invoke CreateFile, addr szFilename, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS\
		, FILE_ATTRIBUTE_NORMAL, NULL
	mov hSaveFile, eax
	invoke WriteFile, hSaveFile, bMatrix, bSize * bSize, addr bOpByte, NULL
	invoke CloseHandle, hSaveFile
	RET
OnSaveFile EndP

OnQuit Proc
	invoke GetProcessHeap
	invoke HeapFree, eax, 0, bMatrix
	
	invoke GetProcessHeap
	invoke HeapFree, eax, 0, bLife

	invoke GetProcessHeap
	invoke HeapFree, eax, 0, bDead

	RET
OnQuit EndP

OnBtnStart Proc
	invoke GetWindowText, hEdtInterval, addr bInterval, lInterval
	invoke StrToInt, addr bInterval	
	.IF eax == 0
		mov eax, 100
	.ENDIF
	invoke SetTimer, hWnd, idTimer1, eax, addr OnGameStart
	mov dwTimerId1, eax

	RET
OnBtnStart EndP

OnDropFile Proc wParam: WPARAM
	LOCAL hDrop:HDROP
	mov eax, wParam
	mov hDrop, eax
	
	invoke DragQueryFile, hDrop, 0, addr szFilename, lFilename

	invoke CreateFile, addr szFilename, GENERIC_READ, 0, NULL, OPEN_EXISTING\
		, FILE_ATTRIBUTE_NORMAL, NULL
	mov hOpenFile, eax
	invoke ReadFile, hOpenFile, bMatrix, bSize * bSize, addr bOpByte, NULL
	invoke CloseHandle, hOpenFile
	invoke InvalidateRect, hWnd, NULL, TRUE
	
	invoke OnBtnStart
	RET
OnDropFile EndP
WndProc Proc hwnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM 
	push hwnd
	pop hWnd
	.IF uMsg == WM_DESTROY 
		invoke PostQuitMessage, NULL
	.ELSEIF uMsg == WM_CREATE
		invoke OnCreate
	.ELSEIF uMsg == WM_PAINT
		invoke OnPaint
	.ELSEIF uMsg == WM_LBUTTONDOWN
		invoke OnLButtonDown, wParam, lParam
	.ELSEIF uMsg == WM_LBUTTONUP
		invoke OnLButtonUp, wParam, lParam
	.ELSEIF uMsg == WM_RBUTTONDOWN
		invoke OnRButtonDown, wParam, lParam
	.ELSEIF uMsg == WM_RBUTTONUP
		invoke OnRButtonUp, wParam, lParam
	.ELSEIF uMsg == WM_MOUSEMOVE
		invoke OnMouseMove, wParam, lParam
	.ELSEIF uMsg == WM_DROPFILES
		invoke OnDropFile, wParam
	.ELSEIF uMsg == WM_QUIT
		invoke OnQuit
	.ELSEIF uMsg == WM_COMMAND
		mov eax, wParam
		.IF lParam == 0
			.IF ax == IDM_EXIT
				invoke PostQuitMessage,0
			.ELSEIF ax == IDM_NEW
				invoke InitMatrix
				invoke InvalidateRect, hWnd, NULL, TRUE
			.ELSEIF ax == IDM_OPEN
				invoke OnOpenFile
			.ELSEIF ax == IDM_SAVE
				invoke OnSaveFile
			.ELSEIF ax == IDM_ABOUT
			.DATA
				szMessage db 'The Game of Life, A model of cell by J.H.Conway, 1970',0Dh,0Ah,0Dh,0Ah\
						      ,' Written by Jianing Yang.',0Dh,0Ah
						      
						   db ' Report bugs to detrox@gmail.com',0Dh,0Ah\
						      ,' Welcome to visit my blog http://blog.jianingy.com', 0Dh,0Ah, 0Dh,0Ah
						      
						 
			.CODE
				invoke MessageBox, hWnd, addr szMessage, addr szAppName, MB_OK
			.ENDIF
		.ELSE
			mov ebx, eax
			shr ebx,16
			.IF bx == BN_CLICKED
				.IF ax == IDC_STEP
					invoke StepOver
				.ELSEIF ax == IDC_START
					invoke OnBtnStart
				.ELSEIF ax == IDC_STOP
					invoke KillTimer, hWnd, dwTimerId1
				.ELSEIF ax == IDC_CLEAR
					invoke InitMatrix
					invoke InvalidateRect, hWnd, NULL, TRUE
				.ENDIF
			.ENDIF
		.ENDIF
	.ELSE
		invoke DefWindowProc, hWnd, uMsg, wParam, lParam
     	ret
	.ENDIF
	xor eax, eax
	RET
WndProc EndP

End Start
