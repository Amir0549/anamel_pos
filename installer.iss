#define AppName "Anamel POS"
#define AppVersion "1.1.5"
#define AppPublisher "Lunaris"

[Setup]
AppId={{A5A9C6B4-7D6E-4E91-9A2F-1C3A8E5B0D74}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\Anamel POS
DefaultGroupName={#AppName}
UninstallDisplayIcon={app}\anamelpos.exe
SetupIconFile=windows\runner\resources\app_icon.ico
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=admin
CloseApplications=yes
OutputDir=build\installer
OutputBaseFilename=AnamelPOS-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\anamelpos.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\anamelpos.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\anamelpos.exe"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent
