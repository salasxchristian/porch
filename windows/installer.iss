; Inno Setup script for PorchSetup-<version>.exe. GitHub Actions builds it;
; by hand, on Windows from the repo root:
;   flutter build windows --release
;   iscc /DAppVersion=0.1.0 windows\installer.iss
; The installer is written to build\installer\.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{F0641127-F247-4062-A8C8-0F9A7EF5F31E}
AppName=Porch
AppVersion={#AppVersion}
AppPublisher=mildpepper
DefaultDirName={autopf}\Porch
DisableProgramGroupPage=yes
OutputDir=..\build\installer
OutputBaseFilename=PorchSetup-{#AppVersion}
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\porch.exe
UninstallDisplayName=Porch
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Per-user install, so updates never need an admin prompt.
PrivilegesRequired=lowest
CloseApplications=yes

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Porch"; Filename: "{app}\porch.exe"
Name: "{autodesktop}\Porch"; Filename: "{app}\porch.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\porch.exe"; Description: "{cm:LaunchProgram,Porch}"; Flags: nowait postinstall skipifsilent
; Porch's updater runs this installer silently; open the new version after.
Filename: "{app}\porch.exe"; Flags: nowait skipifnotsilent
