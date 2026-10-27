; Inno Setup 6 脚本：把 dist 里那份解开的目录做成一个 setup.exe。
;
; 需要 Inno Setup 6（https://jrsoftware.org/isdl.php），装完 iscc.exe 在 PATH 里。
; 正常用法是让 tool/package_windows.ps1 -Inno 调它，参数由脚本传进来：
;   iscc /DAppVersion=1.0.0 /DSourceDir=<dist 里的目录> /DOutputDir=<dist> ai_pet_assistant.iss
; 手工跑也行，那就把下面三段默认值改成实际路径。

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\dist\桌宠日常助手-1.0.0"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist"
#endif

#define AppName "AI桌宠日常助手"
#define AppExe "ai_pet_assistant.exe"
#define AppPublisher "AI桌宠日常助手"

[Setup]
AppId={{8E1B7D42-3F55-4C1A-9A2E-6D0F1B4C7A93}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\AI桌宠日常助手
DefaultGroupName={#AppName}
; 装到用户目录，不弹 UAC：这个程序本身不需要管理员权限，要开机自启也放 HKCU
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=桌宠日常助手-{#AppVersion}-setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName={#AppName}
; 主界面的图放进安装向导，没有就删掉这一行
; SetupIconFile=..\assets\icons\tray_icon.ico

[Languages]
Name: "chinese"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加任务："
Name: "startup"; Description: "开机自动启动"; GroupDescription: "附加任务："; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{group}\卸载 {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Registry]
; 与程序内的 launch_at_startup 写同一处，勾了就由安装器先写好，程序读得到就不会重复写
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; \
    ValueName: "AIPetAssistant"; ValueData: """{app}\{#AppExe}"""; Flags: uninsdeletevalue; Tasks: startup

[Run]
Filename: "{app}\{#AppExe}"; Description: "现在启动"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; 只清程序装的那堆文件；用户数据（Documents\app.db、APPDATA 下的 api_key.bin）留着，
; 卸载不该顺手删掉别人记的东西。要清干净，运行说明.txt 里写了两步。
Type: filesandordirs; Name: "{app}"
