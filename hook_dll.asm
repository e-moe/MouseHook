; Mouse Hook DLL

format PE GUI 4.0 DLL
entry DllEntryPoint

include 'win32axp.inc'

struct MOUSEHOOKSTRUCT
  pt		POINT
  hwnd		dd ?
  wHitTestCode	dd ?
  dwExtraInfo	dd ?
ends

section '.data' data readable writeable

  hInstance dd 0
  hHook     dd ?
  hooked    dd 0

  xHook = 100
  yHook = 100

  clipRect RECT 0,0, ?,?
  hookRect RECT 0,0, ?,?

section '.text' code readable executable

proc DllEntryPoint hinstDLL,fdwReason,lpvReserved
    .if [fdwReason] = DLL_PROCESS_ATTACH
	mov eax,[hinstDLL]
	mov [hInstance],eax
	call Init
    .endif
    mov eax,TRUE
    ret
endp

proc Init uses eax
    invoke GetSystemMetrics,SM_CXSCREEN
    mov    [clipRect.right],  eax
    mov    [hookRect.right],  eax
    sub    eax,xHook
    mov    [hookRect.left],   eax
    invoke GetSystemMetrics,SM_CYSCREEN
    mov    [clipRect.bottom], eax
    mov    [hookRect.bottom], yHook
    ret
endp

proc MouseProc uses ebx, nCode,wParam,lParam
    .if [nCode] >= 0
	mov ebx,[lParam]
	virtual at ebx
	    mhs MOUSEHOOKSTRUCT
	end virtual
	invoke PtInRect,hookRect,[mhs.pt.x],[mhs.pt.y]
	.if eax <> 0
	    .if [hooked] = 0
		invoke ClipCursor,clipRect
		mov [hooked],1
	    .endif
	.else
	    .if [hooked] <> 0
		invoke ClipCursor,NULL
		mov [hooked],0
	    .endif
	.endif
    .endif
    invoke CallNextHookEx,NULL,[nCode],[wParam],[lParam]
    ret
endp

proc InstallHook uses eax
    invoke SetWindowsHookEx,WH_MOUSE,MouseProc,[hInstance],NULL
    mov    [hHook],eax
    ret
endp

proc UninstallHook uses eax
    invoke ClipCursor,NULL
    invoke UnhookWindowsHookEx,[hHook]
    ret
endp

section '.idata' import data readable writeable

  library user32,'USER32.DLL'

  include 'api\user32.inc'

section '.edata' export data readable

  export 'HOOK_DLL.DLL',\
	 InstallHook,'InstallHook',\
	 UninstallHook,'UninstallHook'

section '.reloc' fixups data discardable
