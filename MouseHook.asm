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

  _msg_caption db 'MouseHook',0
  _msg_about db 'MouseHook ver 0.1, Freeware edition.',13,10,\
		'2011 ',0A9h,' Nikolay Labinskiy aka e-moe',13,10,\
		'e-mail: e-moe@ukr.net',0

  _reg_autorun db 'Software\Microsoft\Windows\CurrentVersion\Run',0

  translated  dd ?

  hInstance   dd ?
  menu_nhdl   dd ?
  wnd_hndl    dd ?
  mutex_hndl  dd ?


  WM_TASKBARCREATED dd ?

  wc WNDCLASS 0,WindowProc,0,0,NULL,NULL,NULL,COLOR_BTNFACE+1,NULL,_class
  ntf NOTIFYICONDATA sizeof.NOTIFYICONDATA,0,0,NIF_ICON+NIF_MESSAGE+NIF_TIP,WM_USER+1,0,"MouseHook"
  pt POINT 0,0
  msg MSG

  RC_menu_id = 100
  cmd_About = 101
  cmd_Autorun = 102
  cmd_Config = 103
  cmd_Exit = 104

  hKey dd ?
  KeyAutorunType dd REG_SZ
  DataSize dd MAX_PATH
  ProgrPath db MAX_PATH+3 dup (?)

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
	mov	[hInstance],eax
	mov	[wc.hInstance],eax
	invoke	LoadIcon,0,IDI_ASTERISK
	mov	[wc.hIcon],eax
	invoke	LoadCursor,0,IDC_ARROW
	mov	[wc.hCursor],eax
	invoke	RegisterClass,wc
	.if eax = 0
	   jmp	   exit
	.endif

	invoke	CreateWindowEx,0,_class,_title,0,0,0,0,0,NULL,NULL,[hInstance],NULL
	.if eax = 0
	   jmp	   exit
	.else
	   mov	   [wnd_hndl],eax
	.endif

	invoke	LoadMenu,[hInstance],RC_menu_id
	invoke	GetSubMenu,eax,0
	mov	[menu_nhdl],eax
	invoke	RegOpenKeyEx,HKEY_CURRENT_USER,_reg_autorun,0,KEY_ALL_ACCESS,hKey
	invoke	RegQueryValueEx,[hKey],_title,NULL,KeyAutorunType,ProgrPath,DataSize
	.if eax = ERROR_SUCCESS
	   invoke  CheckMenuItem,[menu_nhdl],cmd_Autorun,MF_BYCOMMAND + MF_CHECKED
	.else
	   invoke  CheckMenuItem,[menu_nhdl],cmd_Autorun,MF_BYCOMMAND + MF_UNCHECKED
	.endif
	invoke	RegCloseKey,[hKey]

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


proc WindowProc uses ebx, hwnd,wmsg,wparam,lparam
  macro .ShowAboutBox
  {
    invoke    MessageBox,0,_msg_about,_msg_caption,MB_OK+MB_ICONINFORMATION
  }

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
	   .elseif [wparam] = cmd_Config
	      invoke  DialogBoxParam,[hInstance],IDD_CONFIG,[wnd_hndl],ConfigDialog,0
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
	      invoke  TrackPopupMenuEx,[menu_nhdl],0,[pt.x],[pt.y],[wnd_hndl],NULL
	      invoke  PostMessage,[wnd_hndl],WM_NULL,0,0
	   .endif

	.elseif eax = [WM_TASKBARCREATED]
	   invoke  Shell_NotifyIcon,NIM_ADD,ntf

	.else
	   invoke  DefWindowProc,[hwnd],[wmsg],[wparam],[lparam]
	.endif

	ret
endp

proc ConfigDialog hwnd_dlg,msg,wparam,lparam
   locals
      height dd ?
      width  dd ?
      error  dd FALSE
   endl
	.if [msg] = WM_INITDIALOG
	   ;TODO: Load params form registry
	   invoke  SetDlgItemInt,[hwnd_dlg],IDC_HEIGHT,0,FALSE
	   invoke  SetDlgItemInt,[hwnd_dlg],IDC_WIDTH,0,FALSE
	   mov eax,TRUE
	.elseif [msg] = WM_CLOSE
	   invoke  EndDialog,[hwnd_dlg],0
	   mov eax,TRUE
	.elseif [msg] = WM_COMMAND
	   .if [wparam] = IDCANCEL
	      invoke  EndDialog,[hwnd_dlg],0
	   .elseif [wparam] = IDOK
	      ;Height
	      invoke  GetDlgItemInt,[hwnd_dlg],IDC_HEIGHT,translated,FALSE
	      .if [translated] = TRUE
		 mov [height], eax
	      .else
		 mov [error], TRUE
	      .endif
	      ;Width
	      invoke  GetDlgItemInt,[hwnd_dlg],IDC_WIDTH,translated,FALSE
	      .if [translated] = TRUE
		 mov [width], eax
	      .else
		 mov [error], TRUE
	      .endif
	      ;Save
	      .if [error] = FALSE
		 ;TODO: Save params to registry
		 ;TODO: Send to hook_dll new params
		 nop
	      .else
		 invoke  MessageBox,0,'Incorrect Width and/or Heigth values.',_msg_caption,MB_OK+MB_ICONERROR
	      .endif
	   .else
	      nop
	      ;invoke  GetDlgItemInt,[hwnd_dlg],ID_ROW,param_buffer,FALSE
	      ;mov     [aepos.caretLine],eax
	      ;mov     [aepos.selectionLine],eax
	      ;invoke  IsDlgButtonChecked,[hwnd_dlg],ID_SELECT
	      ;or      eax,eax
	      ;jz      .position
	   .endif
	   mov eax,TRUE
	.else
	   mov eax,FALSE
	.endif

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

section '.rsrc' resource data readable

  IDD_CONFIG = 301
  IDC_STATIC = -1
  IDC_HEIGHT = 401
  IDC_WIDTH  = 402

  ; resource directory

  directory RT_DIALOG,dialogs,\
	    RT_MENU,menus,\
	    RT_VERSION,versions,\
	    RT_MANIFEST,manifests

  ; resource subdirectories

  resource dialogs,\
	   IDD_CONFIG,LANG_ENGLISH+SUBLANG_DEFAULT,config_dialog

  resource menus,\
	   RC_menu_id,LANG_ENGLISH+SUBLANG_DEFAULT,popup_menu

  resource versions,\
	   1,LANG_NEUTRAL,version

  resource manifests,\
	   1,LANG_NEUTRAL,manifest

  dialog config_dialog,<'MouseHook ',2014h,' Config'>,	0,0,171,54,   DS_3DLOOK+DS_CENTER+DS_MODALFRAME+WS_CAPTION+WS_VISIBLE+WS_POPUP+WS_SYSMENU
    dialogitem 'BUTTON', 'OK',	    IDOK,     110,10,50,14, WS_VISIBLE+WS_TABSTOP+BS_DEFPUSHBUTTON
    dialogitem 'BUTTON', 'C&ancel', IDCANCEL, 110,30,50,14, WS_VISIBLE+WS_TABSTOP+BS_PUSHBUTTON
    dialogitem 'STATIC', 'Enter hookRect params:', IDC_STATIC, 5,5,78,8, WS_VISIBLE+SS_LEFT
    dialogitem 'STATIC', 'Height:', IDC_STATIC, 5, 20,25,8,  WS_VISIBLE+SS_RIGHT
    dialogitem 'STATIC', 'Width:',  IDC_STATIC, 5, 35,25,8,  WS_VISIBLE+SS_RIGHT
    dialogitem 'EDIT',	 '',	    IDC_HEIGHT, 35,20,40,10, WS_VISIBLE+WS_TABSTOP+ES_AUTOHSCROLL+ES_NUMBER
    dialogitem 'EDIT',	 '',	    IDC_WIDTH,	35,35,40,10, WS_VISIBLE+WS_TABSTOP+ES_AUTOHSCROLL+ES_NUMBER
  enddialog

  menu popup_menu
       menuitem '',0,MFR_POPUP+MFR_END
	      menuitem 'About',cmd_About
	      menuseparator
	      menuitem 'Autorun',cmd_Autorun
	      menuitem 'Config',cmd_Config
	      menuseparator
	      menuitem 'Exit',cmd_Exit,MFR_END

  versioninfo version,VOS__WINDOWS32,VFT_APP,VFT2_UNKNOWN,LANG_ENGLISH+SUBLANG_DEFAULT,0,\
	      'FileDescription',<'MouseHook ',2014h,' Multiple screen mouse helper'>,\
	      'ProductName',<'MouseHook ',2014h,' Multiple screen mouse helper'>,\
	      'LegalCopyright',<'2011 ',0A9h,' Nikolay Labinskiy aka e-moe.'>,\
	      'FileVersion','0.1',\
	      'ProductVersion','0.1',\
	      'OriginalFilename','MouseHook.exe'

  resdata manifest
    file 'manifest.xml'
  endres
