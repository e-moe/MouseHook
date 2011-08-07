; MouseHook
; 2011 (c) Nikolay Labinskiy aka e-moe
; e-mail: e-moe@ukr.net

format PE GUI 4.0
entry start

include 'win32axp.inc'

section '.data' data readable writeable

  _title db 'MouseHook',0
  _class db 'MouseHook_class',0

  _mutex db 'MouseHook#@#$$1377',0

  _tskbarrcrt db 'TaskbarCreated',0

  _about db '&About',0
  _autorun db 'Auto&run',0
  _exit  db '&Exit',0

  _msg_caption db 'MouseHook',0
  _msg_about db 'MouseHook ver 0.1, Freeware edition.',13,10,\
		'2011 (c) Nikolay Labinskiy aka e-moe',13,10,\
		'e-mail: e-moe@ukr.net',0

  _reg_autorun db 'Software\Microsoft\Windows\CurrentVersion\Run',0

  _priority dd ?

  menu_nhdl dd ?
  wnd_hndl dd ?
  mutex_hndl dd ?

  target_pid dd ?
  target_hndl dd ?

  WM_TASKBARCREATED dd ?

  wc WNDCLASS 0,WindowProc,0,0,NULL,NULL,NULL,COLOR_BTNFACE+1,NULL,_class
  ntf NOTIFYICONDATA sizeof.NOTIFYICONDATA,0,0,NIF_ICON+NIF_MESSAGE+NIF_TIP,WM_USER+1,0,"MouseHook"
  pt POINT 0,0
  msg MSG

  cmd_About = 1
  cmd_Separator1 = 2
  cmd_Autorun = 3
  cmd_Separator2 = 4
  cmd_Exit = 5

  hKey dd ?
  KeyAutorunType dd REG_SZ
  DataSize dd MAX_PATH
  ProgrPath db MAX_PATH+3 dup (?)

  TokenAccessHandle dd ?


  ERROR_ALREADY_EXISTS = 183
  ERROR_SUCCESS = 0

section '.code' code readable executable

  start:

	invoke	CreateMutex,0,TRUE,_mutex
	mov	[mutex_hndl],eax
	invoke	GetLastError
	.if eax = ERROR_ALREADY_EXISTS
	   jmp	   exit
	.endif

	invoke	GetModuleHandle,0
	mov	[wc.hInstance],eax
	invoke	LoadIcon,0,IDI_ASTERISK
	mov	[wc.hIcon],eax
	invoke	LoadCursor,0,IDC_ARROW
	mov	[wc.hCursor],eax
	invoke	RegisterClass,wc
	.if eax = 0
	   jmp	   exit
	.endif

	invoke	CreateWindowEx,0,_class,_title,0,0,0,0,0,NULL,NULL,[wc.hInstance],NULL
	.if eax = 0
	   jmp	   exit
	.else
	   mov	   [wnd_hndl],eax
	.endif

	invoke	CreatePopupMenu
	mov	[menu_nhdl],eax
	invoke	AppendMenu,[menu_nhdl],MF_STRING,cmd_About,_about
	invoke	AppendMenu,[menu_nhdl],MF_SEPARATOR,cmd_Separator1,0
	invoke	RegOpenKeyEx,HKEY_CURRENT_USER,_reg_autorun,0,KEY_ALL_ACCESS,hKey
	invoke	RegQueryValueEx,[hKey],_title,NULL,KeyAutorunType,ProgrPath,DataSize
	.if eax = ERROR_SUCCESS
	   invoke  AppendMenu,[menu_nhdl],MF_STRING+MF_CHECKED,cmd_Autorun,_autorun
	.else
	   invoke  AppendMenu,[menu_nhdl],MF_STRING,cmd_Autorun,_autorun
	.endif
	invoke	RegCloseKey,[hKey]
	invoke	AppendMenu,[menu_nhdl],MF_SEPARATOR,cmd_Separator2,0
	invoke	AppendMenu,[menu_nhdl],MF_STRING,cmd_Exit,_exit

	mov	eax,[wnd_hndl]
	mov	[ntf.hWnd],eax
	mov	eax,[wc.hIcon]
	mov	[ntf.hIcon],eax
	invoke	Shell_NotifyIcon,NIM_ADD,ntf

	invoke	RegisterWindowMessage,_tskbarrcrt
	mov	[WM_TASKBARCREATED],eax

	invoke	ClipCursor,NULL
	invoke	InstallHook

  msg_loop:
	invoke	GetMessage,msg,NULL,0,0
	.if eax <> 0
	   invoke  TranslateMessage,msg
	   invoke  DispatchMessage,msg
	   jmp	   msg_loop
	.endif

	invoke	Shell_NotifyIcon,NIM_DELETE,ntf
  exit:
	invoke	ReleaseMutex,[mutex_hndl]
	invoke	UninstallHook
	invoke	ExitProcess,[msg.wParam]


proc WindowProc hwnd,wmsg,wparam,lparam
  macro .ShowAboutBox
  {
    invoke    MessageBox,0,_msg_about,_msg_caption,MB_OK+MB_ICONINFORMATION
  }

	push	ebx esi edi
	mov	eax,[wmsg]
	.if eax = WM_DESTROY
	   invoke  PostQuitMessage,0
	   xor	   eax,eax
	.elseif eax = WM_CLOSE
	   invoke  DestroyWindow,[wnd_hndl]

	.elseif eax = WM_COMMAND
	   .if [wparam] = cmd_About
	      .ShowAboutBox
	   .elseif [wparam] = cmd_Exit
	      invoke  PostMessage,[wnd_hndl],WM_CLOSE,0,0
	   .elseif [wparam] = cmd_Autorun
	      invoke  GetMenuState,[menu_nhdl],cmd_Autorun,MF_BYCOMMAND
	      and     eax,MF_CHECKED
	      .if eax <> 0
		 invoke  CheckMenuItem,[menu_nhdl],cmd_Autorun,MF_BYCOMMAND + MF_UNCHECKED
		 invoke  RegOpenKeyEx,HKEY_CURRENT_USER,_reg_autorun,0,KEY_ALL_ACCESS,hKey
		 invoke  RegDeleteValue,[hKey],_title
		 invoke  RegCloseKey,[hKey]
	      .else
		 invoke  CheckMenuItem,[menu_nhdl],cmd_Autorun,MF_BYCOMMAND + MF_CHECKED
		 mov	 [ProgrPath],'"'
		 invoke  GetModuleFileName,NULL,ProgrPath+1,MAX_PATH
		 mov	 ebx,eax
		 mov	 [ProgrPath+ebx+1],'"'
		 mov	 [ProgrPath+ebx+2],0
		 add	 ebx,3
		 invoke  RegOpenKeyEx,HKEY_CURRENT_USER,_reg_autorun,0,KEY_ALL_ACCESS,hKey
		 invoke  RegSetValueEx,[hKey],_title,0,REG_SZ,ProgrPath,ebx
		 invoke  RegCloseKey,[hKey]
	      .endif
	   .endif
	.elseif eax = WM_USER+1
	   .if [lparam] = WM_LBUTTONDBLCLK
	      .ShowAboutBox
	   .elseif [lparam] = WM_RBUTTONUP
	      invoke  SetForegroundWindow,[wnd_hndl]
	      invoke  GetCursorPos,pt
	      invoke  TrackPopupMenu,[menu_nhdl],0,[pt.x],[pt.y],0,[wnd_hndl],0
	      invoke  PostMessage,[wnd_hndl],WM_NULL,0,0
	   .endif

	.elseif eax = [WM_TASKBARCREATED]
	   invoke  Shell_NotifyIcon,NIM_ADD,ntf

	.else
	   invoke  DefWindowProc,[hwnd],[wmsg],[wparam],[lparam]
	.endif

	pop	edi esi ebx
	ret
endp


section '.idata' import data readable writeable

  library kernel32,'KERNEL32.DLL',\
	  user32,'USER32.DLL',\
	  shell32,'SHELL32.DLL',\
	  advapi32,'ADVAPI32.DLL',\
	  hook_dll,'HOOK_DLL.DLL'

  include 'api\kernel32.inc'
  include 'api\user32.inc'
  include 'api\shell32.inc'
  include 'api\advapi32.inc'

  import hook_dll,\
	 InstallHook,'InstallHook',\
	 UninstallHook,'UninstallHook'
