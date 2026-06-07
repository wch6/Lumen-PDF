#define AppName "Lumen PDF"
#define AppExeName "lumen.exe"
#define AppPublisher "com.codex"

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

#ifndef RepoRoot
  #define RepoRoot ".."
#endif

#ifndef SourceDir
  #define SourceDir "..\build\windows\x64\runner\Release"
#endif

#ifndef OutputDir
  #define OutputDir "..\build\installer\dist"
#endif

#ifndef OutputBaseFilename
  #define OutputBaseFilename "LumenPDF-Setup-" + AppVersion
#endif

[Setup]
AppId={{C61F1DFD-59CE-4ED1-9D5F-C8E5B01D785C}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppMutex=LumenPDF
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableDirPage=no
DisableProgramGroupPage=no
UsePreviousAppDir=yes
UsePreviousGroup=yes
UninstallDisplayIcon={app}\{#AppExeName}
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBaseFilename}
SetupIconFile={#RepoRoot}\assets\icons\app_icon.ico
VersionInfoVersion={#AppVersion}
VersionInfoCompany={#AppPublisher}
VersionInfoDescription={#AppName} Installer
VersionInfoProductName={#AppName}
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
WizardStyle=modern
Compression=lzma2/ultra64
SolidCompression=yes
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
#ifndef NoDesktopShortcut
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
#endif

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"
#ifndef NoDesktopShortcut
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon
#endif

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[Code]
var
  DeleteUserData: Boolean;

procedure DeleteDirIfExists(Path: String);
begin
  if DirExists(Path) then
    DelTree(Path, True, True, True);
end;

function InitializeUninstall(): Boolean;
begin
  DeleteUserData := False;
  if not UninstallSilent then
  begin
    DeleteUserData :=
      MsgBox(
        '是否同时删除 Lumen PDF 生成的所有用户数据和缓存？' + #13#10 + #13#10 +
        '这包括设置、最近文件、阅读位置、便签、高亮和本地缓存数据库。' + #13#10 +
        '不会删除你的原始 PDF 文件。',
        mbConfirmation,
        MB_YESNO or MB_DEFBUTTON2
      ) = IDYES;
  end;
  Result := True;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if (CurUninstallStep = usPostUninstall) and DeleteUserData then
  begin
    DeleteDirIfExists(ExpandConstant('{localappdata}\LumenPDF'));
    DeleteDirIfExists(ExpandConstant('{localappdata}\PDFReader'));
    DeleteDirIfExists(ExpandConstant('{localappdata}\pdf_reader'));
    DeleteDirIfExists(ExpandConstant('{localappdata}\com.codex\pdf_reader\pdf_reader'));
    DeleteDirIfExists(ExpandConstant('{userappdata}\pdf_reader'));
    DeleteDirIfExists(ExpandConstant('{userappdata}\com.codex\pdf_reader\pdf_reader'));
  end;
end;
