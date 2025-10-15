; VPN Client Demo 安装脚本
; 参考 FlClash 的打包方式

#define MyAppName "VPN Client Demo"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Your Name"
#define MyAppURL "https://github.com/yourname/vpn-client-demo"
#define MyAppExeName "demo2.exe"

[Setup]
; 应用信息
AppId={{8F3E9B2C-4A5D-4E7F-9C1B-2D8A6F3E7C9D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; 安装目录
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

; 输出配置
OutputDir=..\..\..\dist
OutputBaseFilename=VPN_Client_Demo_Setup_{#MyAppVersion}
SetupIconFile=..\..\runner\resources\app_icon.ico

; 压缩
Compression=lzma
SolidCompression=yes

; 权限
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog

; Windows 版本要求
MinVersion=10.0.17763
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

; 界面
WizardStyle=modern
DisableWelcomePage=no

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "autostart"; Description: "开机自动启动"; GroupDescription: "其他选项:"

[Files]
; 主程序和所有依赖
Source: "..\..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; 注意：这会复制所有文件，包括 sing-box.exe, demo2.exe, DLL, data/ 等

[Icons]
; 开始菜单图标
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
; 桌面图标
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; 安装完成后运行
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// 自动启动相关代码
procedure CurStepChanged(CurStep: TSetupStep);
var
  TaskName: String;
  ExePath: String;
begin
  if CurStep = ssPostInstall then
  begin
    if WizardIsTaskSelected('autostart') then
    begin
      TaskName := '{#MyAppName}';
      ExePath := ExpandConstant('{app}\{#MyAppExeName}');
      
      // 创建计划任务实现开机自动启动
      Exec('schtasks.exe', 
        '/Create /F /SC ONLOGON /TN "' + TaskName + '" /TR "' + ExePath + '" /RL HIGHEST',
        '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    end;
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  TaskName: String;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    TaskName := '{#MyAppName}';
    
    // 删除计划任务
    Exec('schtasks.exe', 
      '/Delete /F /TN "' + TaskName + '"',
      '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

