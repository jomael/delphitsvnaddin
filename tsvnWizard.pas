(*
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU Lesser General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *)

unit tsvnWizard;

{$R 'icons.res'}
{$R 'Strings.res'}

interface

uses
  ToolsAPI, SysUtils, Windows, Dialogs, Menus, Registry, ShellApi,
  Classes, Controls, Graphics, ImgList, ExtCtrls, ActnList, XMLIntf;

const
  VERSION = '1.6.0';

const
  SVN_PROJECT_EXPLORER = 0;
  SVN_LOG_PROJECT = 1;
  SVN_LOG_FILE = 2;
  SVN_CHECK_MODIFICATIONS = 3;
  SVN_ADD = 4;                                                             
  SVN_UPDATE = 5;
  SVN_COMMIT = 6;
  SVN_DIFF = 7;
  SVN_REVERT = 8;
  SVN_REPOSITORY_BROWSER = 9;
  SVN_EDIT_CONFLICT = 10;
  SVN_CONFLICT_OK = 11;
  SVN_CREATE_PATCH = 12;
  SVN_USE_PATCH = 13;
  SVN_CLEAN = 14;
  SVN_IMPORT = 15;
  SVN_CHECKOUT = 16;
  SVN_BLAME = 17;
  SVN_SETTINGS = 18;
  SVN_ABOUT = 19;
  SVN_UPDATE_REV = 20;
  SVN_SEPERATOR_1 = 21;
  SVN_ABOUT_PLUGIN = 22;
  SVN_PLUGIN_PROJ_SETTINGS = 23;
  SVN_VERB_COUNT = 24;

var
  TSVNPath: string;
  TMergePath: string;
  Bitmaps: array[0..SVN_VERB_COUNT-1] of TBitmap;
  Actions: array[0..SVN_VERB_COUNT-1] of TAction;
  {$ifdef DEBUG}
  DebugFile: TextFile;
  {$endif}

type
  TProjectMenuTimer = class;

  TTortoiseSVN = class(TNotifierObject, IOTANotifier, IOTAWizard,
                       INTAProjectMenuCreatorNotifier)
  strict private
    IsPopup: Boolean;
    IsProject: Boolean;
    IsEditor: Boolean;
    CmdFiles: string;
    Timer: TTimer;
    TSvnMenu: TMenuItem;
    IsDirectory: Boolean;

    function GetVerb(Index: Integer): string;
    function GetVerbState(Index: Integer): Word;
    
    procedure Tick( sender: TObject );
    procedure DiffClick( sender: TObject );
    procedure LogClick(Sender : TObject);
    procedure ConflictClick(Sender: TObject);
    procedure ConflictOkClick(Sender: TObject);
    procedure ExecuteVerb(Index: Integer);

    procedure UpdateAction( sender: TObject );
    procedure ExecuteAction( sender: TObject );

    function GetCurrentModule(): IOTAModule;
    function GetCurrentSourceEditor(): IOTASourceEditor;
    procedure GetCurrentModuleFileList( fileList: TStrings );

    function FindMenu(Item: TComponent): TMenu;
  private
    ProjectMenuTimer: TProjectMenuTimer;
    
    procedure TSVNMenuClick( Sender: TObject );
    procedure CreateMenu; overload;
    procedure CreateMenu(Parent: TMenuItem; const Ident: string = ''); overload;

    ///  <summary>
    ///  Returns the path for the TortoiseSVN command depending on the files in
    ///  a project. This includes entries such as ..\..\MyUnit.pas.
    ///  </summary>
    function GetPathForProject(Project: IOTAProject): string;

    procedure GetFiles(Files: TStringList);

    function CheckModified(Project: IOTAProject): Integer;

    class procedure TSVNExec( Params: string );
    class procedure TSVNMergeExec( Params: string );
  public
    constructor Create;
    destructor Destroy; override;

    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;
    procedure Execute;

    { INTAProjectMenuCreatorNotifier }

    { The result will be inserted into the project manager local menu. Menu
      may have child menus. }
    function AddMenu(const Ident: string): TMenuItem;

    { Return True if you wish to install a project manager menu item for this
      ident.  In cases where the project manager node is a file Ident will be
      a fully qualified file name. }
    function CanHandle(const Ident: string): Boolean;
  end;

  TIdeNotifier = class(TNotifierObject, IOTAIDENotifier)
  protected
    { This procedure is called for many various file operations within the
      IDE }
    procedure FileNotification(NotifyCode: TOTAFileNotification;
      const FileName: string; var Cancel: Boolean);

    { This function is called immediately before the compiler is invoked.
      Set Cancel to True to cancel the compile }
    procedure BeforeCompile(const Project: IOTAProject; var Cancel: Boolean); overload;

    { This procedure is called immediately following a compile.  Succeeded
      will be true if the compile was successful }
    procedure AfterCompile(Succeeded: Boolean); overload;

    { The associated item is being destroyed so all references should be dropped.
      Exceptions are ignored. }
    procedure Destroyed;

    class function RegisterPopup(Module: IOTAModule): Boolean; overload;

    class function RegisterPopup(View: IOTAEditView): Boolean; overload;

    class procedure RegisterEditorNotifier(Module: IOTAModule);
    class procedure RemoveEditorNotifier(Module: IOTAModule);
  end;

  TModuleArray = array of IOTAModule;

  TModuleNotifier = class(TModuleNotifierObject, IOTAModuleNotifier)
  strict private
    _FileName: string;
    _Notifier: Integer;
    _Module: IOTAModule;
  protected
    { This procedure is called immediately after the item is successfully saved.
      This is not called for IOTAWizards }
    procedure AfterSave;

    { The associated item is being destroyed so all references should be dropped.
      Exceptions are ignored. }
    procedure Destroyed;
  public
    constructor Create(Filename: string; Module: IOTAModule);
    destructor Destroy; override;

    procedure RemoveBindings;

    property FileName: string read _FileName write _FileName;
  end;

  TProjectNotifier = class(TModuleNotifierObject, IOTAProjectNotifier)
  strict private
    FModuleCount: Integer;
    FModules: TModuleArray;
    FProject: IOTAProject;
    FFileName: String;

    procedure SetModuleCount(const Value: Integer);
  private
    function GetModule(Index: Integer): IOTAModule;
    procedure SetModule(Index: Integer; const Value: IOTAModule);
  protected
    { IOTAModuleNotifier }

    { User has renamed the module }
    procedure ModuleRenamed(const NewName: string); overload;

    { IOTAProjectNotifier }

    { This notifier will be called when a file/module is added to the project }
    procedure ModuleAdded(const AFileName: string);

    { This notifier will be called when a file/module is removed from the project }
    procedure ModuleRemoved(const AFileName: string);

    { This notifier will be called when a file/module is renamed in the project }
    procedure ModuleRenamed(const AOldFileName, ANewFileName: string); overload;

    { The associated item is being destroyed so all references should be dropped.
      Exceptions are ignored. }
    procedure Destroyed;

    constructor Create(const FileName: string);   

    property ModuleCount: Integer read FModuleCount write SetModuleCount;

    property Modules: TModuleArray read FModules write FModules;

    property Module[Index: Integer]: IOTAModule read GetModule write SetModule;

    property Project: IOTAProject read FProject write FProject;
  end;

  TProjectMenuTimer = class(TTimer)
  private
    procedure TimerTick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
  end;

  TEditorNotifier = class(TNotifierObject, IOTAEditorNotifier, IOTANotifier)
  strict private
    _Editor: IOTAEditor;
    _Notifier: Integer;
    _Opened: Boolean;
  public
    constructor Create(const Editor: IOTAEditor);                  
    destructor Destroy; override;

    { This associated item was modified in some way. This is not called for
      IOTAWizards }
    procedure Modified;

    { This procedure is called immediately after the item is successfully saved.
      This is not called for IOTAWizards }
    procedure AfterSave;

    { Called when a new edit view is created(opInsert) or destroyed(opRemove) }
    procedure ViewNotification(const View: IOTAEditView; Operation: TOperation);

    { Called when a view is activated }
    procedure ViewActivated(const View: IOTAEditView);

    procedure RemoveBindings;

    { The associated item is being destroyed so all references should be dropped.
      Exceptions are ignored. }
    procedure Destroyed;

    property Opened: Boolean read _Opened write _Opened;
  end;

{$IFNDEF DLL_MODE}

procedure Register;

{$ELSE}

function InitWizard(const BorlandIDEServices: IBorlandIDEServices;
  RegisterProc: TWizardRegisterProc;
  var Terminate: TWizardTerminateProc): Boolean; stdcall;

{$ENDIF}

implementation

uses TypInfo, Contnrs, UHelperFunctions, IniFiles, UFmProjectSettings;

var
  MenuCreatorNotifier: Integer = -1;
  IDENotifierIndex   : Integer = -1;
  NotifierList : TStringList;
  TortoiseSVN: TTortoiseSVN;
  EditPopup: TPopupMenu;
  EditMenuItem: TMenuItem;
  ImgIdx: array[0..SVN_VERB_COUNT] of Integer;
  EditorNotifierList: TStringList;
  ModifiedFiles: TStringList;
  ModuleNotifierList: TStringList;

procedure WriteDebug(Text: string);
const
  LogFile = 'c:\TSVNDebug.log';
begin
{$ifdef DEBUG}
  try
    AssignFile(DebugFile, 'c:\TSVNDebug.log');
    if (FileExists(LogFile)) then
      Append(DebugFile)
    else
      ReWrite(DebugFile);
  except
  end;

  try
    WriteLn(DebugFile, Text);
  except
  end;

  try
    CloseFile(DebugFile);
  except
  end;
{$endif}
end;

function GetBitmapName(Index: Integer): string;
begin
  case Index of
    SVN_PROJECT_EXPLORER:
      Result:= 'explorer';
    SVN_LOG_PROJECT,
    SVN_LOG_FILE:
      Result:= 'log';
    SVN_CHECK_MODIFICATIONS:
      Result:= 'check';
    SVN_ADD:
      Result:= 'add';
    SVN_UPDATE,
    SVN_UPDATE_REV:
      Result:= 'update';
    SVN_COMMIT:
      Result:= 'commit';
    SVN_DIFF:
      Result:= 'diff';
    SVN_REVERT:
      Result:= 'revert';
    SVN_REPOSITORY_BROWSER:
      Result:= 'repository';
    SVN_SETTINGS:
      Result:= 'settings';
    SVN_PLUGIN_PROJ_SETTINGS:
      Result := 'projsettings';
    SVN_ABOUT,
    SVN_ABOUT_PLUGIN:
      Result:= 'about';
    SVN_EDIT_CONFLICT:
      Result := 'edconflict';
    SVN_CONFLICT_OK:
      Result := 'conflictok';
    SVN_CREATE_PATCH:
      Result := 'crpatch';
    SVN_USE_PATCH:
      Result := 'usepatch';
    SVN_CLEAN:
      Result := 'clean';
    SVN_IMPORT:
      Result := 'import';
    SVN_CHECKOUT:
      Result := 'checkout';
    SVN_BLAME:
      Result := 'blame';
  end;
end;

function TTortoiseSVN.GetCurrentModule: IOTAModule;
begin
  Result := (BorlandIDEServices as IOTAModuleServices).CurrentModule;
end;

procedure TTortoiseSVN.GetCurrentModuleFileList( FileList: TStrings );
var
  ModServices: IOTAModuleServices;
  Module: IOTAModule;
  Project: IOTAProject;
  ModInfo: IOTAModuleInfo;
  FileName: string;
begin
  FileList.Clear;

  if (IsPopup) and (not IsEditor) then
  begin
    Project := (BorlandIDEServices as IOTAProjectManager).GetCurrentSelection(FileName);

    ModInfo := Project.FindModuleInfo(FileName);
    if (ModInfo <> nil) then
    begin
      GetModuleFiles(FileList, ModInfo.OpenModule);
    end;
  end else
  begin
    ModServices := BorlandIDEServices as IOTAModuleServices;
    if (ModServices <> nil) then
    begin
      Module := ModServices.CurrentModule;
      GetModuleFiles(FileList, Module);
    end;
  end;
end;

function TTortoiseSVN.GetCurrentSourceEditor: IOTASourceEditor;
var
  CurrentModule: IOTAModule;
  Editor: IOTAEditor; 
  I: Integer;
begin
  Result := nil;
  CurrentModule := GetCurrentModule;
  if (Assigned(CurrentModule)) then
  begin
    for I := 0 to CurrentModule.ModuleFileCount - 1 do
    begin
      Editor := CurrentModule.ModuleFileEditors[I];
      
      if Supports(Editor, IOTASourceEditor, Result) then
        Exit;
    end;
  end;
end;

procedure TTortoiseSVN.GetFiles(Files: TStringList);
var
  Ident: string;
  Project: IOTAProject;
  ItemList: TStringList;
  ModInfo: IOTAModuleInfo;
begin
  if (IsPopup) and (not IsEditor) then
  begin
    {
      The call is from the Popup and a file is selected
    }
    Ident := '';
    Project := (BorlandIDEServices as IOTAProjectManager).GetCurrentSelection(Ident);

    ItemList := TStringList.Create;
    try
      ModInfo := Project.FindModuleInfo(Ident);
      if (ModInfo <> nil) then
      begin
        GetModuleFiles(ItemList, ModInfo.OpenModule);

        Files.AddStrings(ItemList);
      end else
      begin
        if (DirectoryExists(Ident)) then
          Files.Add(Ident);
      end;
    finally
      ItemList.Free;
    end;
  end else
  begin
    GetCurrentModuleFileList(Files);
  end;
end;

procedure GetModifiedItems( ItemList: TStrings );
begin
  ItemList.Clear;
  
  if Assigned(ModifiedFiles) and (ModifiedFiles.Count > 0) then
  begin
    ItemList.AddStrings(ModifiedFiles);
  end;
end;

function TTortoiseSVN.AddMenu(const Ident: string): TMenuItem;
begin
  {
    Get's created every time a user right-clicks a file or project.
  }
  Result := TMenuItem.Create(nil);
  Result.Name := 'Submenu';
  Result.Caption := 'TortoiseSVN';
  Result.OnClick := TSVNMenuClick;

  if (SameText(Ident, sFileContainer)) then
  begin
    CreateMenu(Result, sFileContainer);
    Result.Tag := 1;
  end
  else if (SameText(Ident, sProjectContainer)) then
  begin
    CreateMenu(Result, sProjectContainer);
    Result.Tag := 2;
  end
  else if (SameText(Ident, sDirectoryContainer)) then
  begin
    CreateMenu(Result, sDirectoryContainer);
    Result.Tag := 8;
  end;

  // Disable for now - didn't work properly
  // ProjectMenuTimer := TProjectMenuTimer.Create(Result);
end;

function TTortoiseSVN.CanHandle(const Ident: string): Boolean;
begin
  Result := SameText(Ident, sFileContainer) or
            SameText(Ident, sProjectContainer) or
            SameText(Ident, sDirectoryContainer);
end;

function TTortoiseSVN.CheckModified(Project: IOTAProject): Integer;
var
  ItemList: TStringList;
  ModifiedItems: Boolean;
  ModifiedItemsMessage: string;
  I: Integer;
begin
  Result := mrNo;

  ItemList := TStringList.Create;
  try
    GetModifiedItems(ItemList);
    ModifiedItems := (ItemList.Count > 0);

    if ModifiedItems then
    begin
      ModifiedItemsMessage := GetString(25) + #13#10#13#10;
      for I := 0 to ItemList.Count-1 do
        ModifiedItemsMessage := ModifiedItemsMessage + '    ' + ItemList[I] + #13#10;
      ModifiedItemsMessage := ModifiedItemsMessage + #13#10 + GetString(26);
    end;
  finally
    ItemList.Free;
  end;

  if ModifiedItems then
  begin
    Result := MessageDlg( ModifiedItemsMessage, mtWarning, [mbYes, mbNo, mbCancel], 0 );
  end;
end;

procedure TTortoiseSVN.ConflictClick(Sender: TObject);
var
  Files: TStringList;
  Item: TComponent;
begin
  if (Sender is TComponent) then
  begin
    Item := TComponent(Sender);

    Files := TStringList.Create;
    try
      GetFiles(Files);

      if (Files.Count > 1) then
        TSVNExec( '/command:conflicteditor /notempfile /path:' + AnsiQuotedStr( Files[Item.Tag], '"' ) )
      else if (Files.Count = 1) then
        TSVNExec( '/command:conflicteditor /notempfile /path:' + AnsiQuotedStr( Files[0], '"' ) );
    finally
      Files.Free;
    end;
  end;
end;

procedure TTortoiseSVN.ConflictOkClick(Sender: TObject);
var
  Files: TStringList;
  Item: TComponent;
begin
  if (Sender is TComponent) then
  begin
    Item := TComponent(Sender);

    Files := TStringList.Create;
    try
      GetFiles(Files);

      if (Files.Count > 1) then
        TSVNExec( '/command:resolve /notempfile /path:' + AnsiQuotedStr( Files[Item.Tag], '"' ) )
      else if (Files.Count = 1) then
        TSVNExec( '/command:resolve /notempfile /path:' + AnsiQuotedStr( Files[0], '"' ) );
    finally
      Files.Free;
    end;
  end;
end;

constructor TTortoiseSVN.Create;
var
  Reg: TRegistry;
  I: Integer;
// defines for 64-bit registry access, copied from Windows include file
// (older IDE versions won't find them otherwise)
const
  KEY_WOW64_64KEY = $0100;
  KEY_WOW64_32KEY = $0200;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_LOCAL_MACHINE;
    if Reg.OpenKeyReadOnly( '\SOFTWARE\TortoiseSVN' ) then
    begin
      TSVNPath   := Reg.ReadString( 'ProcPath' );
      TMergePath := Reg.ReadString( 'TMergePath' );
    end
    else
    begin
      //try 64 bit registry
      Reg.Access := Reg.Access or KEY_WOW64_64KEY;
      if Reg.OpenKeyReadOnly( '\SOFTWARE\TortoiseSVN' ) then
      begin
        TSVNPath   := Reg.ReadString( 'ProcPath' );
        TMergePath := Reg.ReadString( 'TMergePath' );
      end
      else begin
          //try WOW64 bit registry
          Reg.Access := Reg.Access or KEY_WOW64_32KEY;
          if Reg.OpenKeyReadOnly( '\SOFTWARE\TortoiseSVN' ) then
          begin
            TSVNPath   := Reg.ReadString( 'ProcPath' );
            TMergePath := Reg.ReadString( 'TMergePath' );
          end;
      end;
    end;
  finally
    Reg.CloseKey;
    Reg.Free;
  end;

  TSvnMenu:= nil;

  Timer := TTimer.Create(nil);
  Timer.Interval := 200;
  Timer.OnTimer := Tick;
  Timer.Enabled := True;

  TortoiseSVN := Self;

  for I := 0 to SVN_VERB_COUNT do
  begin
    ImgIdx[I] := -1;
  end;
end;

procedure TTortoiseSVN.CreateMenu(Parent: TMenuItem; const Ident: string = '');
var
  Item: TMenuItem;
  I: Integer;
  Menu: TMenu;
  MenuType: Integer;
begin
  if (Parent = nil) then Exit;

  Menu := FindMenu(Parent);

  // Little speed-up (just running "SameText" once instead of every iteration
  if (SameText(Ident, sFileContainer)) then
    MenuType := 1
  else if (SameText(Ident, sDirectoryContainer)) then
    MenuType := 2
  else if (SameText(Ident, sProjectContainer)) then
    MenuType := 3
  else if (Ident <> '') then
    MenuType := 4
  else
    MenuType := 0;

  for I := 0 to SVN_VERB_COUNT - 1 do
  begin
    if (MenuType <> 0) then
    begin
      // Ignore the project specific entries for the file container
      if (MenuType = 1) and
         (I in [SVN_PROJECT_EXPLORER, SVN_LOG_PROJECT, SVN_REPOSITORY_BROWSER, SVN_IMPORT, SVN_CHECKOUT, SVN_CLEAN, SVN_USE_PATCH, SVN_PLUGIN_PROJ_SETTINGS]) then
        Continue;

      // Ignore the project and some file specific entries for the directory container
      if (MenuType = 2) and
         (I in [SVN_PROJECT_EXPLORER, SVN_LOG_PROJECT, SVN_REPOSITORY_BROWSER, SVN_IMPORT, SVN_CHECKOUT, SVN_CLEAN, SVN_USE_PATCH, SVN_CONFLICT_OK, SVN_EDIT_CONFLICT, SVN_PLUGIN_PROJ_SETTINGS]) then
        Continue;

      // Ignore the file specific entries for the project container
      if (MenuType = 3) and
         (I in [SVN_LOG_FILE, SVN_DIFF, SVN_CONFLICT_OK, SVN_EDIT_CONFLICT]) then
        Continue;

      // Ignore about and settings in the popup
      if (I in [SVN_ABOUT, SVN_SETTINGS, SVN_ABOUT_PLUGIN]) then
        Continue;
    end;

    if (Bitmaps[I] = nil) then
    begin
      Bitmaps[I] := TBitmap.Create;
      try
        Bitmaps[I].LoadFromResourceName( HInstance, getBitmapName(i) );
      except
      end;
    end;

    if (Actions[I] = nil) then
    begin
      Actions[I] := TAction.Create(nil);
      Actions[I].ActionList := (BorlandIDEServices as INTAServices).ActionList;
      Actions[I].Caption := GetVerb(I);
      Actions[I].Hint := GetVerb(I);

      if (Bitmaps[I].Width = 16) and (Bitmaps[I].height = 16) then
      begin
        Actions[I].ImageIndex := (BorlandIDEServices as INTAServices).AddMasked(Bitmaps[I], clBlack);
      end;

      Actions[I].OnUpdate:= UpdateAction;
      Actions[I].OnExecute:= ExecuteAction;
      Actions[I].Tag := I;
    end;

    Item := TMenuItem.Create(Parent);
    if (I <> SVN_DIFF) and
       (I <> SVN_LOG_FILE) and
       (I <> SVN_EDIT_CONFLICT) and
       (I <> SVN_CONFLICT_OK) then
    begin
      Item.Action := Actions[I];
    end
    else
    begin
      if (Item.ImageIndex = -1) then
      begin
        if (Menu <> nil) then
          Item.ImageIndex := Menu.Images.AddMasked(Bitmaps[I], clBlack)
      end;
    end;
    Item.Tag := I;

    Parent.Add(Item);
  end;
end;

procedure TTortoiseSVN.Tick(Sender: TObject);
var
  Intf: INTAServices;
  I, X, Index: Integer;
  Project: IOTAProject;
  Notifier: TProjectNotifier;
begin
  if (BorlandIDEServices.QueryInterface(INTAServices, Intf) = S_OK) then
  begin
    Self.CreateMenu;
    Timer.Free;
    Timer := nil;
  end;

  for I := 0 to (BorlandIDEServices as IOTAModuleServices).ModuleCount - 1 do
  begin
    TIdeNotifier.RegisterPopup((BorlandIDEServices as IOTAModuleServices).Modules[I]);
    TIdeNotifier.RegisterEditorNotifier((BorlandIDEServices as IOTAModuleServices).Modules[I]);

    if (Supports((BorlandIDEServices as IOTAModuleServices).Modules[I], IOTAProject, Project)) then
    begin
      Notifier := TProjectNotifier.Create(Project.FileName);
      Notifier.Project := Project;
      Notifier.ModuleCount := Project.GetModuleFileCount;
      for X := 0 to Notifier.ModuleCount - 1 do
      begin
        Notifier.Module[X] := Project.ModuleFileEditors[X].Module;
      end;

      Index := Project.AddNotifier(Notifier as IOTAProjectNotifier);
      if (Index >= 0) then
        NotifierList.AddObject(Project.FileName, Pointer(Index));
    end;
  end;
end;

procedure TTortoiseSVN.TSVNMenuClick( Sender: TObject );
var
  ItemList, Files: TStringList;
  I: integer;
  Diff, Log, Item, Conflict, ConflictOk: TMenuItem;
  Ident: string;
  Parent: TMenuItem;
  Project: IOTAProject;
  ModInfo: IOTAModuleInfo;
begin
  // update the diff item and submenu; the diff action is handled by the
  // menu item itself, not by the action list
  // the 'log file' item behaves in a similar way

  if (Sender is TMenuItem) then
    Parent := TMenuItem(Sender)
  else
    Exit;

  IsPopup := (Parent.Tag > 0);

  IsProject := (Parent.Tag and 2) = 2;

  IsEditor := (Parent.Tag and 4) = 4;

  IsDirectory := (Parent.Tag and 4) = 4;

  Diff := nil; Log := nil; Conflict := nil; ConflictOk := nil;

  for I := 0 to Parent.Count - 1 do
  begin
    if (Parent.Items[I].Tag = SVN_DIFF) then
    begin
      Diff := Parent.Items[I];
      Diff.Action:= nil;
      Diff.OnClick:= nil;
      Diff.Enabled:= False;
      Diff.Clear;
    end
    else if (Parent.Items[I].Tag = SVN_LOG_FILE) then
    begin
      Log := Parent.Items[I];
      Log.Action := nil;
      Log.OnClick := nil;
      Log.Enabled := False;
      Log.Clear();
    end
    else if (Parent.Items[I].Tag = SVN_EDIT_CONFLICT) then
    begin
      Conflict := Parent.Items[I];
      Conflict.Action := nil;
      Conflict.OnClick := nil;
      Conflict.Enabled := False;
      Conflict.Clear();
    end
    else if (Parent.Items[I].Tag = SVN_CONFLICT_OK) then
    begin
      ConflictOk := Parent.Items[I];
      ConflictOk.Action := nil;
      ConflictOk.OnClick := nil;
      ConflictOk.Enabled := False;
      ConflictOk.Clear();
    end;
  end;

  Files := TStringList.create;

  if (IsPopup) and (not IsEditor) then
  begin
    {
      The call is from the Popup and a file is selected
    }
    Ident := '';
    Project := (BorlandIDEServices as IOTAProjectManager).GetCurrentSelection(Ident);

    ItemList := TStringList.Create;
    try
      ModInfo := Project.FindModuleInfo(Ident);
      if (ModInfo <> nil) then
      begin
        GetModuleFiles(ItemList, ModInfo.OpenModule);

        Files.AddStrings(ItemList);
      end else
      begin
        if (DirectoryExists(Ident)) then
          Files.Add(Ident);
      end;
    finally
      ItemList.Free;
    end;
  end else
  begin
    GetCurrentModuleFileList(Files);
  end;

  CmdFiles := '';
  for I := 0 to Files.Count - 1 do
  begin
    CmdFiles := CmdFiles + Files[I];
    if (I < Files.Count - 1) then
      CmdFiles := CmdFiles + '*';
  end;

  if Files.Count > 0 then
  begin
    if (Diff <> nil) then
    begin
      Diff.Enabled:= True;
      Diff.Caption:= GetString(SVN_DIFF);
      if (not IsPopup) then
      begin
        Diff.ImageIndex := Actions[SVN_DIFF].ImageIndex;
      end;
    end;

    if (Log <> nil) then
    begin
      Log.Enabled := True;
      Log.Caption := GetString(SVN_LOG_FILE);
      if (not IsPopup) then
        Log.ImageIndex := Actions[SVN_LOG_FILE].ImageIndex;
    end;

    if (Conflict <> nil) then
    begin
      Conflict.Enabled := True;
      Conflict.Caption := GetString(SVN_EDIT_CONFLICT);
      if (not IsPopup) then
        Conflict.ImageIndex := Actions[SVN_EDIT_CONFLICT].ImageIndex;
    end;

    if (ConflictOk <> nil) then
    begin
      ConflictOk.Enabled := True;
      ConflictOk.Caption := GetString(SVN_CONFLICT_OK);
      if (not IsPopup) then
        ConflictOk.ImageIndex := Actions[SVN_CONFLICT_OK].ImageIndex;
    end;

    if Files.Count > 1 then
    begin
      for I := 0 to Files.Count - 1 do begin
        if (Diff <> nil) then
        begin
          Item := TMenuItem.Create(diff);
          Item.Caption:= ExtractFileName( files[i] );
          Item.OnClick:= DiffClick;
          Item.Tag:= I;
          Diff.Add(Item);
        end;

        if (Log <> nil) then
        begin
          Item := TMenuItem.Create(log);
          Item.Caption := ExtractFileName( files[i] );
          Item.OnClick := LogClick;
          Item.Tag := I;
          Log.Add(Item);
        end;

        if (Conflict <> nil) then
        begin
          Item := TMenuItem.Create(log);
          Item.Caption := ExtractFileName( files[i] );
          Item.OnClick := ConflictClick;
          Item.Tag := I;
          Conflict.Add(Item);
        end;

        if (ConflictOk <> nil) then
        begin
          Item := TMenuItem.Create(log);
          Item.Caption := ExtractFileName( files[i] );
          Item.OnClick := ConflictOkClick;
          Item.Tag := I;
          ConflictOk.Add(Item);
        end;
      end;
    end else
    begin  // files.Count = 1
      if (Diff <> nil) then
      begin
        Diff.Caption:= GetString(SVN_DIFF) + ' ' + ExtractFileName( Files[0] );
        Diff.OnClick:= DiffClick;
      end;

      if (Log <> nil) then
      begin
        Log.Caption := GetString(SVN_LOG_FILE) + ' ' + ExtractFileName( Files[0] );
        Log.OnClick := LogClick;
      end;

      if (Conflict <> nil) then
      begin
        Conflict.Caption := GetString(SVN_EDIT_CONFLICT) + ' ' + ExtractFileName( Files[0] );
        Conflict.OnClick := ConflictClick;
      end;

      if (ConflictOk <> nil) then
      begin
        ConflictOk.Caption := GetString(SVN_CONFLICT_OK) + ' ' + ExtractFileName( Files[0] );
        ConflictOk.OnClick := ConflictOkClick;
      end;
    end;
  end;
  Files.free;
end;

class procedure TTortoiseSVN.TSVNMergeExec(params: string);
var
  cmdLine: AnsiString;
begin
  cmdLine:= AnsiString( TMergePath + ' ' + params );
  WinExec( pansichar(cmdLine), SW_SHOW );
end;

procedure TTortoiseSVN.DiffClick( Sender: TObject );
var
  Files: TStringList;
  Item: TComponent;
begin
  if (Sender is TComponent) then
  begin
    Item := TComponent(Sender);

    Files := TStringList.Create;
    try
      GetFiles(Files);

      if (Files.Count > 1) then
        TSVNExec( '/command:diff /notempfile /path:' + AnsiQuotedStr( Files[Item.Tag], '"' ) )
      else if (Files.Count = 1) then
        TSVNExec( '/command:diff /notempfile /path:' + AnsiQuotedStr( Files[0], '"' ) );
    finally
      Files.Free;
    end;
  end;
end;

procedure TTortoiseSVN.LogClick(Sender : TObject);
var
  Files : TStringList;
  Item  : TComponent;
begin
  if (Sender is TComponent) then
  begin
    Item  := TComponent(Sender);

    Files := TStringList.Create;
    try
      GetFiles(Files);

      if (Files.Count > 1) then
        TSVNExec('/command:log /notempfile /path:' + AnsiQuotedStr(Files[Item.Tag], '"'))
      else if (Files.Count = 1) then
        TSVNExec('/command:log /notempfile /path:' + AnsiQuotedStr(Files[0], '"'));
    finally
      Files.Free;
    end;
  end;
end;

procedure TTortoiseSVN.CreateMenu;
var
  MainMenu: TMainMenu;
  ProjManager: IOTAProjectManager;
  Services: IOTAServices;
begin
  if (TSvnMenu <> nil) then exit;

  TSvnMenu := TMenuItem.Create(nil);
  TSvnMenu.Caption := 'TortoiseSVN';
  TSvnMenu.Name := 'TortoiseSVNMain';
  TSvnMenu.OnClick := TSVNMenuClick;

  CreateMenu(TSvnMenu);

  MainMenu := (BorlandIDEServices as INTAServices).MainMenu;
  MainMenu.Items.Insert(MainMenu.Items.Count-1, TSvnMenu);

  if Supports(BorlandIDEServices, IOTAProjectManager, ProjManager) then
  begin
    MenuCreatorNotifier := ProjManager.AddMenuCreatorNotifier(Self);
  end;

  if Supports(BorlandIDEServices, IOTAServices, Services) then
  begin
    IDENotifierIndex := Services.AddNotifier(TIdeNotifier.Create);
  end;
end;

destructor TTortoiseSVN.Destroy;
var
  I: Integer;
begin
  if (TSvnMenu <> nil) then
  begin
    TSvnMenu.free;
  end;

  for I := Low(Actions) to High(Actions) do
  begin
    try
      if (Actions[I] <> nil) then
        Actions[I].Free;
    except
    end;
  end;

  for I := Low(Bitmaps) to High(Bitmaps) do
  begin
    try
      if (Bitmaps[I] <> nil) then
        Bitmaps[I].Free;
    except
    end;
  end;

  TortoiseSVN := nil;

  inherited;
end;

function TTortoiseSVN.GetVerb(Index: Integer): string;
begin
  Result := GetString(index);
  Exit;
end;

const vsEnabled = 1;

function TTortoiseSVN.GetVerbState(Index: Integer): Word;
begin
  Result:= 0;
  case index of
    SVN_PROJECT_EXPLORER:
      if GetCurrentProject <> nil then
        Result:= vsEnabled;
    SVN_LOG_PROJECT:
      if GetCurrentProject <> nil then
        Result:= vsEnabled;
    SVN_LOG_FILE:
      // this verb state is updated by the menu itself
      ;
    SVN_CHECK_MODIFICATIONS:
      if GetCurrentProject <> nil then
        Result:= vsEnabled;
    SVN_ADD:
      if GetCurrentProject <> nil then
        Result:= vsEnabled;
    SVN_UPDATE,
    SVN_UPDATE_REV:
      if GetCurrentProject <> nil then
        Result:= vsEnabled;
    SVN_COMMIT:
      if GetCurrentProject <> nil then
        Result:= vsEnabled;
    SVN_DIFF:
      // this verb state is updated by the menu itself
      ;
    SVN_REVERT:
      if GetCurrentProject <> nil then
        Result:= vsEnabled;
    SVN_REPOSITORY_BROWSER:
      Result:= vsEnabled;
    SVN_SETTINGS,
    SVN_PLUGIN_PROJ_SETTINGS:
      Result:= vsEnabled;
    SVN_ABOUT,
    SVN_ABOUT_PLUGIN:
      Result:= vsEnabled;
    SVN_EDIT_CONFLICT,
    SVN_CONFLICT_OK:
      // these verb's state is updated by the menu itself
      ;
    SVN_CREATE_PATCH:
      Result := vsEnabled;
    SVN_USE_PATCH:
      Result := vsEnabled;
    SVN_CLEAN:
      Result := vsEnabled;
    SVN_IMPORT:
      Result := vsEnabled;
    SVN_CHECKOUT:
      Result := vsEnabled;
    SVN_BLAME:
      if GetCurrentProject <> nil then
        Result := vsEnabled;
  end;
end;

class procedure TTortoiseSVN.TSVNExec( Params: string );
var
  CmdLine: AnsiString;
begin
  CmdLine := AnsiString(TSVNPath + ' ' + params );
  WinExec( pansichar(cmdLine), SW_SHOW );
end;

procedure TTortoiseSVN.ExecuteVerb(Index: Integer);
var
  Project: IOTAProject;
  Response: Integer;
  FileName, Cmd: string;
  SourceEditor: IOTASourceEditor;
  Line: Integer;
  FmProjectSettings: TFmProjectSettings;
begin
  Project := GetCurrentProject();

  case index of
    SVN_PROJECT_EXPLORER:
      if (not IsPopup) or (IsProject) then
      begin
        {
          If it's a project which is accessed via the popup menu, then that
          project needs to be loaded and not the popup of the current file
          in the editor.
        }
        if (IsProject) then
        begin
          Project := (BorlandIDEServices as IOTAProjectManager).GetCurrentSelection(FileName);
        end;

        if (Project <> nil) then
          ShellExecute( 0, 'open', pchar( ExtractFilePath(Project.GetFileName) ), '', '', SW_SHOWNORMAL );
      end;
    SVN_LOG_PROJECT:
      if (not IsPopup) or (IsProject) then
      begin
        {
          If it's a project which is accessed via the popup menu, then that
          project needs to be loaded and not the popup of the current file
          in the editor.
        }
        if (IsProject) then
        begin
          Project := (BorlandIDEServices as IOTAProjectManager).GetCurrentSelection(FileName);
        end;

        if (Project <> nil) then
          TSVNExec( '/command:log /notempfile /path:' + AnsiQuotedStr( ExtractFilePath(Project.FileName), '"' ) );
      end;
    SVN_LOG_FILE:
        // this verb is handled by its menu item
        ;
    SVN_CHECK_MODIFICATIONS:
      if ((not IsPopup) or (IsProject)) and (not IsEditor) then
      begin
        {
          If it's a project which is accessed via the popup menu, then that
          project needs to be loaded and not the popup of the current file
          in the editor.
        }
        if (IsProject) then
        begin
          Project := (BorlandIDEServices as IOTAProjectManager).GetCurrentSelection(FileName);
        end;

        if (Project <> nil) then
          TSVNExec( '/command:repostatus /notempfile /path:' + AnsiQuotedStr( GetPathForProject(Project), '"' ) );
      end else
      begin
        {
          The call is from the Popup and a file is selected
        }
        Cmd := '/command:repostatus /notempfile /path:' + AnsiQuotedStr(CmdFiles, '"');

        TSVNExec(Cmd);
      end;
    SVN_ADD:
      if (not IsPopup) or (IsProject) then
      begin
        {
          If it's a project which is accessed via the popup menu, then that
          project needs to be loaded and not the popup of the current file
          in the editor.
        }
        if (IsProject) then
        begin
          Project := (BorlandIDEServices as IOTAProjectManager).GetCurrentSelection(FileName);
        end;

        if (Project <> nil) then
          TSVNExec( '/command:add /notempfile /path:' + AnsiQuotedStr( ExtractFilePath(Project.GetFileName), '"' ) );
      end else
      begin
        {
          The call is from the Popup and a file is selected
        }
        Cmd := '/command:add /notempfile /path:' + AnsiQuotedStr(CmdFiles, '"');

        TSVNExec(Cmd);
      end;
    SVN_UPDATE,
    SVN_UPDATE_REV:
      if (not IsPopup) or (IsProject) then
      begin
        {
          If it's a project which is accessed via the popup menu, then that
          project needs to be loaded and not the popup of the current file
          in the editor.
        }
        if (IsProject) then
        begin
          Project := (BorlandIDEServices as IOTAProjectManager).GetCurrentSelection(FileName);
        end;

        if (Project <> nil) then
        begin
          Response := CheckModified(Project);

          if (Response = mrYes) then
          begin
            (BorlandIDEServices as IOTAModuleServices).SaveAll;
            // If all files are saved none are left modified (some *.dfm files were still counted as being modified)
            ModifiedFiles.Clear;
          end
          else if (Response = mrCancel) then
            Exit;

          Cmd := '/command:update /notempfile';
          if (index = SVN_UPDATE_REV) then
            Cmd := Cmd + ' /rev';
          Cmd := Cmd + ' /path:' + AnsiQuotedStr( GetPathForProject(Project), '"');

          TSVNExec(Cmd);
        end;
      end else
      begin
        {
          The call is from the Popup and a file is selected
        }
        Cmd := '/command:update /notempfile';
        if (index = SVN_UPDATE_REV) then
          Cmd := Cmd + ' /rev';
        Cmd := Cmd + ' /path:' + AnsiQuotedStr(CmdFiles, '"');

        TSVNExec(Cmd);
      end;
    SVN_BLAME:
      begin
        {
          The call is from the Popup and a file is selected
        }
        Cmd := '/command:blame /notempfile /startrev:1 /endrev:-1 /path:' + AnsiQuotedStr(CmdFiles, '"');

        Line := -1;

        SourceEditor := GetCurrentSourceEditor;
        if (IsPopup) and (Assigned(SourceEditor)) then
        begin
          if (SourceEditor.EditViewCount > 0) then
          begin
            try
              Line := SourceEditor.EditViews[0].Position.Row;
            except
              Line := -1;
            end;
          end;
        end;

        if (Line > -1) then
          Cmd := Cmd + ' /line:' + IntToStr(Line);

        TSVNExec(Cmd);
      end;
    SVN_COMMIT:
      if (not IsPopup) or (IsProject) then
      begin
        {
          If it's a project which is accessed via the popup menu, then that
          project needs to be loaded and not the popup of the current file
          in the editor.
        }
        if (IsProject) then
        begin
          Project := (BorlandIDEServices as IOTAProjectManager).GetCurrentSelection(FileName);
        end;
            
        if (Project <> nil) then
        begin
          Response := CheckModified(Project);
          
          if (Response = mrYes) then
          begin
            (BorlandIDEServices as IOTAModuleServices).SaveAll;
            // If all files are saved none are left modified (some *.dfm files were still counted as being modified)
            ModifiedFiles.Clear;
          end
          else if (Response = mrCancel) then
            Exit;

          TSVNExec( '/command:commit /notempfile /path:' + AnsiQuotedStr( GetPathForProject(Project), '"' ) );
        end;
      end else
      begin
        {
          The call is from the Popup and a file is selected
        }
        Cmd := '/command:commit /notempfile /path:' + AnsiQuotedStr(CmdFiles, '"');

        TSVNExec(Cmd);
      end;
    SVN_DIFF:
        // this verb is handled by its menu item
        ;
    SVN_REVERT:
      if (not IsPopup) or (IsProject) then
      begin
        {
          If it's a project which is accessed via the popup menu, then that
          project needs to be loaded and not the popup of the current file
          in the editor.
        }
        if (IsProject) then
        begin
          Project := (BorlandIDEServices as IOTAProjectManager).GetCurrentSelection(FileName);
        end;
            
        if (Project <> nil) then
          TSVNExec( '/command:revert /notempfile /path:' + AnsiQuotedStr( GetPathForProject(Project), '"' ) );
      end else
      begin
        {
          The call is from the Popup and a file is selected
        }
        Cmd := '/command:revert /notempfile /path:' + AnsiQuotedStr(CmdFiles, '"');

        TSVNExec(Cmd);
      end;
    SVN_REPOSITORY_BROWSER:
      if (not IsPopup) or (IsProject) then
      begin
        {
          If it's a project which is accessed via the popup menu, then that
          project needs to be loaded and not the popup of the current file
          in the editor.
        }
        if (IsProject) then
        begin
          Project := (BorlandIDEServices as IOTAProjectManager).GetCurrentSelection(FileName);
        end;

        if (Project <> nil) then
          TSVNExec( '/command:repobrowser /notempfile /path:' + AnsiQuotedStr( ExtractFilePath(project.GetFileName), '"' ) )
        else
          TSVNExec( '/command:repobrowser' );
      end;
    SVN_SETTINGS:
        TSVNExec( '/command:settings' );
    SVN_PLUGIN_PROJ_SETTINGS:
      begin
        FmProjectSettings := TFmProjectSettings.Create(nil);
        try
          if (IsProject) then
          begin
            Project := (BorlandIDEServices as IOTAProjectManager).GetCurrentSelection(FileName);
          end;
          FmProjectSettings.Project := Project;
          
          FmProjectSettings.ShowModal;
        finally
          FmProjectSettings.Free;
        end;
      end;
    SVN_ABOUT:
        TSVNExec( '/command:about' );
    SVN_ABOUT_PLUGIN:
      ShowMessage(Format(GetString(30), [VERSION]));
    SVN_EDIT_CONFLICT,
    SVN_CONFLICT_OK:
        // these verbs are handled by their menu item
        ;
    SVN_CREATE_PATCH:
      if (not IsPopup) or (IsProject) then
      begin
        {
          If it's a project which is accessed via the popup menu, then that
          project needs to be loaded and not the popup of the current file
          in the editor.
        }
        if (IsProject) then
        begin
          Project := (BorlandIDEServices as IOTAProjectManager).GetCurrentSelection(FileName);
        end;
            
        if (Project <> nil) then
          TSVNExec( '/command:createpatch /notempfile /path:' + AnsiQuotedStr( ExtractFilePath(Project.GetFileName), '"' ) );
      end else
      begin
        {
          The call is from the Popup and a file is selected
        }
        Cmd := '/command:createpatch /notempfile /path:' + AnsiQuotedStr(CmdFiles, '"');

        TSVNExec(Cmd);
      end;
    SVN_USE_PATCH:
      if (not IsPopup) or (IsProject) then
      begin
        {
          If it's a project which is accessed via the popup menu, then that
          project needs to be loaded and not the popup of the current file
          in the editor.
        }
        if (IsProject) then
        begin
          Project := (BorlandIDEServices as IOTAProjectManager).GetCurrentSelection(FileName);
        end;

        if (Project <> nil) then
          TSVNMergeExec( '/patchpath:' + AnsiQuotedStr( ExtractFilePath(Project.GetFileName), '"' ) );
      end;
    SVN_CLEAN:
      if (not IsPopup) or (IsProject) then
      begin
        {
          If it's a project which is accessed via the popup menu, then that
          project needs to be loaded and not the popup of the current file
          in the editor.
        }
        if (IsProject) then
        begin
          Project := (BorlandIDEServices as IOTAProjectManager).GetCurrentSelection(FileName);
        end;

        if (Project <> nil) then
          TSVNExec( '/command:cleanup /notempfile /path:' + AnsiQuotedStr( ExtractFilePath(Project.GetFileName), '"' ) )
      end;
    SVN_IMPORT:
        if (Project <> nil) then
          TSVNExec( '/command:import /notempfile /path:' + AnsiQuotedStr( ExtractFilePath(Project.GetFileName), '"' ) );
    SVN_CHECKOUT:
        if (Project <> nil) then
          TSVNExec( '/command:checkout /notempfile /path:' + AnsiQuotedStr( ExtractFilePath(Project.GetFileName), '"' ) )
        else
          TSVNExec( '/command:checkout /notempfile' );
  end;
end;

function TTortoiseSVN.FindMenu(Item: TComponent): TMenu;
begin
  if (Item = nil) then
  begin
    Result := nil;
    Exit;
  end;

  if (Item is TMenu) then
  begin
    Result := TMenu(Item);
    Exit;
  end else
    Result := FindMenu(Item.Owner);
end;

procedure TTortoiseSVN.UpdateAction( sender: TObject );
var action: TAction;
begin
  action:= sender as TAction;
  action.Enabled := getVerbState( action.tag ) = vsEnabled;
end;

procedure TTortoiseSVN.ExecuteAction( sender: TObject );
var action: TAction;
begin
  action:= sender as TAction;
  executeVerb( action.tag );
end;

function TTortoiseSVN.GetIDString: string;
begin
  result:= 'Subversion.TortoiseSVN';
end;

function TTortoiseSVN.GetName: string;
begin
  result:= 'TortoiseSVN add-in';
end;

function TTortoiseSVN.GetPathForProject(Project: IOTAProject): string;
var
  I: Integer;
  Path: TStringList;
  ModInfo: IOTAModuleInfo;
  FilePath: string;

  ///  <summary>
  ///  Removes all subdirectories so that only the root directories are given
  ///  to TortoiseSVN.
  ///  </summary>
  function RemoveSubdirs(List: TStringList): Boolean;
  var
    I, X: Integer;
    Dir1, Dir2: string;
  begin
    Result := False;
    for I := 0 to List.Count - 1 do
    begin
      Dir1 := List.Strings[I];

      // Remove also empty entries
      if (Dir1 = '') then
      begin
        List.Delete(I );
        Result := True;
        Exit;
      end;

      for X := 0 to List.Count - 1 do
      begin
        if (X = I) then Continue;

        Dir2 := List.Strings[X];

        if (Length(Dir2) > Length(Dir1)) then
        begin
          if (Copy(Dir2, 1, Length(Dir1)) = Dir1) then
          begin
            List.Delete(X);
            Result := True;
            Exit;
          end;
        end;
      end;
    end;
  end;

begin
  Path := TStringList.Create;
  try
    Path.Sorted := True;
    Path.Add(ExtractFilePath(Project.FileName));


    for I := 0 to Project.GetModuleCount - 1 do
    begin
      ModInfo := Project.GetModule(I);
      if (ModInfo.ModuleType <> omtPackageImport) and
         (ModInfo.ModuleType <> omtTypeLib) then
      begin
        FilePath := ExtractFilePath(ModInfo.FileName);
        if (Path.IndexOf(FilePath) = -1) then
          Path.Add(FilePath);
      end;
    end;

    Path.AddStrings(GetDirectoriesFromTSVN(Project));

    while (RemoveSubdirs(Path)) do;

    Result := '';
    for I := 0 to Path.Count - 1 do
    begin
      Result := Result + Path.Strings[I];
      if (I < Path.Count - 1) then
        Result := Result + '*';
    end;
  finally
    Path.Free;
  end;
end;

function TTortoiseSVN.GetState: TWizardState;
begin
  result:= [wsEnabled];
end;

procedure TTortoiseSVN.Execute;
begin
  // empty
end;

{$IFNDEF DLL_MODE}

procedure Register;
begin
  RegisterPackageWizard(TTortoiseSVN.create);
end;

{$ELSE}

var wizardID: integer;

procedure FinalizeWizard;
var
  WizardServices: IOTAWizardServices;
begin
  Assert(Assigned(BorlandIDEServices));

  WizardServices := BorlandIDEServices as IOTAWizardServices;
  Assert(Assigned(WizardServices));

  WizardServices.RemoveWizard(wizardID);
end;

function InitWizard(const BorlandIDEServices: IBorlandIDEServices;
  RegisterProc: TWizardRegisterProc;
  var Terminate: TWizardTerminateProc): Boolean; stdcall;
var
  WizardServices: IOTAWizardServices;
begin
  Assert(BorlandIDEServices <> nil);
  Assert(ToolsAPI.BorlandIDEServices = BorlandIDEServices);

  Terminate := FinalizeWizard;

  WizardServices := BorlandIDEServices as IOTAWizardServices;
  Assert(Assigned(WizardServices));

  wizardID:= WizardServices.AddWizard(TTortoiseSVN.Create as IOTAWizard);

  result:= wizardID >= 0;
end;


exports
  InitWizard name WizardEntryPoint;

{$ENDIF}

{ TIdeNotifier }

procedure TIdeNotifier.AfterCompile(Succeeded: Boolean);
begin
  // empty
end;

procedure TIdeNotifier.BeforeCompile(const Project: IOTAProject;
  var Cancel: Boolean);
begin
  // empty
end;

procedure TIdeNotifier.Destroyed;
begin
  WriteDebug('TIdeNotifier.Destroyed');

  inherited;
end;

function IsProjectFile(const FileName: string; var Project: IOTAProject): Boolean;
var
  Module  : IOTAModule;
  ProjectGroup : IOTAProjectGroup;
begin
  Module := (BorlandIDEServices as IOTAModuleServices).FindModule(FileName);
  Result := Supports(Module, IOTAProject, Project) and
            not Supports(Module, IOTAProjectGroup, ProjectGroup);
end;

procedure TIdeNotifier.FileNotification(NotifyCode: TOTAFileNotification;
  const FileName: string; var Cancel: Boolean);
var
  Project  : IOTAProject;
  Module   : IOTAModule;
  I, Index : Integer;
  Notifier : TProjectNotifier;
begin
  WriteDebug('TIdeNotifier.FileNotification :: start');
  case NotifyCode of
    ofnFileOpened:
    begin
      if IsProjectFile(FileName, Project) then
      begin
        Notifier := TProjectNotifier.Create(FileName);
        Notifier.Project := Project;
        Notifier.ModuleCount := Project.GetModuleFileCount;
        for I := 0 to Notifier.ModuleCount - 1 do
        begin
          Notifier.Module[I] := Project.ModuleFileEditors[I].Module;
        end;

        Index := Project.AddNotifier(Notifier as IOTAProjectNotifier);
        if (Index >= 0) then
          NotifierList.AddObject(FileName, Pointer(Index));
      end else
      begin
        Module := (BorlandIDEServices as IOTAModuleServices).FindModule(FileName);
        if not Assigned(Module) then Exit;

        RegisterPopup(Module);
        
        RegisterEditorNotifier(Module);
      end;
    end;
    ofnProjectDesktopLoad:
    begin
      // FileName = *.dsk
      for I := 0 to (BorlandIDEServices as IOTAModuleServices).ModuleCount - 1 do
      begin
        Module := (BorlandIDEServices as IOTAModuleServices).Modules[I];

        RegisterPopup(Module);

        RegisterEditorNotifier(Module);
      end;
    end;
    ofnFileClosing :
    begin
      Module := (BorlandIDEServices as IOTAModuleServices).FindModule(FileName);
      if (not Assigned(Module)) then Exit;

      if NotifierList.Find(FileName, I) then
      begin
        Index := Integer(NotifierList.Objects[I]);
        NotifierList.Delete(I);
        Module.RemoveNotifier(Index);
      end;

      RemoveEditorNotifier(Module);

      // If a project is closed, remove all the modified files from the list
      if IsProjectFile(FileName, Project) then
      begin
        ModifiedFiles.Clear;
      end;
    end;
  end;

  WriteDebug('TIdeNotifier.FileNotification :: done');
end;


class function TIdeNotifier.RegisterPopup(Module: IOTAModule): Boolean;
var
  I, K: Integer;
  Editor: IOTAEditor;
  SourceEditor: IOTASourceEditor;
begin
  WriteDebug('TIdeNotifier.RegisterPopup :: start');

  Result := False;

  for I := 0 to Module.GetModuleFileCount - 1 do
  begin
    Editor := nil;
    try
      Editor := Module.GetModuleFileEditor(I);
    except
    end;

    if Assigned(Editor) and Supports(Editor, IOTASourceEditor, SourceEditor) then
    begin
      for K := 0 to SourceEditor.EditViewCount - 1 do
      begin
        Result := RegisterPopup(SourceEditor.EditViews[K]);
        if (Result) then Exit;
      end;
    end;
  end;

  WriteDebug('TIdeNotifier.RegisterPopup :: done');
end;

class procedure TIdeNotifier.RegisterEditorNotifier(Module: IOTAModule);
var
  I: Integer;
  Editor: IOTAEditor;
  EditorNotifier: TEditorNotifier;
  SourceEditor: IOTASourceEditor;
begin
  WriteDebug('TIdeNotifier.RegisterEditorNotifier :: start');

  for I := 0 to Module.GetModuleFileCount - 1 do
  begin
    Editor := nil;
    try
      Editor := Module.GetModuleFileEditor(I);
    except
    end;

    if (Assigned(Editor)) then
    begin
      if (EditorNotifierList.IndexOf(Editor.FileName) = -1) then
      begin
        EditorNotifier := TEditorNotifier.Create(Editor);
        if (Supports(Editor, IOTASourceEditor, SourceEditor)) then
        begin
          {
            It can happen that no view is reported at this time so we need
            to add the entry for the popup menu in the editor at a later time.
          }
          if (SourceEditor.EditViewCount = 0) then
            EditorNotifier.Opened := False;
        end;
        
        EditorNotifierList.AddObject(Editor.FileName, EditorNotifier);
      end;
    end;
  end;

  WriteDebug('TIdeNotifier.RegisterEditorNotifier :: done');
end;

class function TIdeNotifier.RegisterPopup(View: IOTAEditView): Boolean;
begin
  WriteDebug('TIdeNotifier.RegisterPopup :: start');

  if (Assigned(EditMenuItem)) then
  begin
    Result := True;
    Exit;
  end;
  
  if (EditPopup = nil) then
  begin
    try
      EditPopup := (View.GetEditWindow.Form.FindComponent('EditorLocalMenu') as TPopupMenu);
    except
    end;
  end;

  if (not Assigned(EditPopup)) then
  begin
    Result := False;
    Exit;
  end;

  if (EditMenuItem = nil) then
  begin
    EditMenuItem := TMenuItem.Create(EditPopup);
    EditMenuItem .Caption := 'TortoiseSVN';
    EditMenuItem.Visible := True;
    EditMenuItem.Tag := 4 or 1;
    EditMenuItem.OnClick := TortoiseSVN.TSVNMenuClick;
      
    TortoiseSVN.CreateMenu(EditMenuItem, sFileContainer);
    EditPopup.Items.Add(EditMenuItem);
  end;
  Result := True;
end;

class procedure TIdeNotifier.RemoveEditorNotifier(Module: IOTAModule);
var
  Editor: IOTAEditor;
  I, Idx: Integer;
  EditorNotifier: TEditorNotifier;
begin
  WriteDebug('TIdeNotifier.RemoveEditorNotifier (' + Module.FileName + ')');

  for I := 0 to Module.GetModuleFileCount - 1 do
  begin
    WriteDebug('TIdeNotifier.RemoveEditorNotifier :: ' + IntToStr(I));
    Editor := nil;
    try
      Editor := Module.GetModuleFileEditor(I);
    except
    end;

    if (Assigned(Editor)) then
    begin
      try
        if (EditorNotifierList.Find(Editor.FileName, Idx)) then
        begin
          EditorNotifier := TEditorNotifier(EditorNotifierList.Objects[Idx]);
          EditorNotifierList.Delete(Idx);
          EditorNotifier.RemoveBindings;
        end;
      except
      end;
    end;
  end;

  WriteDebug('TIdeNotifier.RemoveEditorNotifier :: done');
end;

{ TProjectNotifier }

constructor TProjectNotifier.Create(const FileName: string);
begin
  inherited Create;

  FFileName := FileName;
end;

procedure TProjectNotifier.Destroyed;
begin
  WriteDebug('TProjectNotifier.Destroyed');

  inherited;
end;

function TProjectNotifier.GetModule(Index: Integer): IOTAModule;
begin
  Result := FModules[Index];
end;

procedure TProjectNotifier.ModuleRenamed(const AOldFileName,
  ANewFileName: string);
var
  I, Index : Integer;
  EditorNotifier: TEditorNotifier;
  ModuleNotifier: TModuleNotifier; 
begin
  WriteDebug('TProjectNotifier.ModuleRenamed (' + AOldFileName + ' to ' + ANewFileName + ')');

  if NotifierList.Find(AOldFileName, I) then
  begin
    WriteDebug('NotifierList Index: ' + IntToStr(I));
    Index := Integer(NotifierList.Objects[I]);
    NotifierList.Delete(I);
    NotifierList.AddObject(ANewFileName, Pointer(Index));
  end;

  if ModuleNotifierList.Find(AOldFileName, I) then
  begin
    WriteDebug('ModuleNotifierList Index: ' + IntToStr(I));
    ModuleNotifier := TModuleNotifier(ModuleNotifierList.Objects[I]);
    ModuleNotifier.FileName := ANewFileName;
    ModuleNotifierList.Delete(I);
    ModuleNotifierList.AddObject(ANewFileName, ModuleNotifier);
  end;

  if EditorNotifierList.Find(AOldFileName, I) then
  begin
    WriteDebug('EditorNotifierList Index: ' + IntToStr(I));
    EditorNotifier := TEditorNotifier(EditorNotifierList.Objects[I]);
    EditorNotifierList.Delete(I);
    EditorNotifierList.AddObject(ANewFileName, EditorNotifier);
  end;

  FFileName := ANewFileName;
end;

procedure TProjectNotifier.ModuleRenamed(const NewName: string);
begin
  ModuleRenamed(FFileName, NewName);
end;

procedure RemoveIDENotifier;
var
  Services : IOTAServices;
begin
  WriteDebug('RemoveIDENotifier :: start');
  if IDENotifierIndex > -1 then
  begin
    Services := BorlandIDEServices as IOTAServices;
    Assert(Assigned(Services), 'IOTAServices not available');
    Services.RemoveNotifier(IDENotifierIndex);
    IDENotifierIndex := -1;
  end;
  WriteDebug('RemoveIDENotifier :: done');
end;

procedure FinalizeNotifiers;
var
  I, Index : Integer;
  ModServices : IOTAModuleServices;
  Module : IOTAModule;
begin
  WriteDebug('FinalizeNotifiers :: start');
  if not Assigned(NotifierList) then Exit;
  ModServices := BorlandIDEServices as IOTAModuleServices;

  try
    Assert(Assigned(ModServices), 'IOTAModuleServices not available');

    for I := 0 to NotifierList.Count -1 do
    begin
      WriteDebug('FinalizeNotifiers :: Notifier ' + IntToStr(I + 1) + ' / ' + IntToStr(NotifierList.Count));

      Index := Integer(NotifierList.Objects[I]);
      Module := ModServices.FindModule(NotifierList[I]);
      if Assigned(Module) then
      begin
        Module.RemoveNotifier(Index);
      end;
    end;
  finally
    FreeAndNil(NotifierList);
  end;
  WriteDebug('FinalizeNotifiers :: done');
end;

procedure FinalizeEditorNotifiers;
var
  I : Integer;
  EditorNotifier: TEditorNotifier;
begin
  WriteDebug('FinalizeEditorNotifiers :: start');
  if not Assigned(EditorNotifierList) then Exit;

  try
    for I := 0 to EditorNotifierList.Count -1 do
    begin
      WriteDebug('FinalizeEditorNotifiers :: Notifier ' + IntToStr(I + 1) + ' / ' + IntToStr(EditorNotifierList.Count));
      EditorNotifier := TEditorNotifier(EditorNotifierList.Objects[I]);
      EditorNotifier.RemoveBindings;
      try
        EditorNotifier.Free;
      except
      end;
    end;
  finally
    FreeAndNil(EditorNotifierList);
  end;
  WriteDebug('FinalizeEditorNotifiers :: done');
end;

procedure TProjectNotifier.SetModule(Index: Integer; const Value: IOTAModule);
begin
  FModules[Index] := Value;
end;

procedure TProjectNotifier.SetModuleCount(const Value: Integer);
begin
  FModuleCount := Value;
  SetLength(FModules, FModuleCount);
end;

procedure TProjectNotifier.ModuleAdded(const AFileName: string);
var
  ModInfo: IOTAModuleInfo;
  Module: IOTAModule;
begin
  WriteDebug('TProjectNotifier.ModuleAdded (' + AFileName + ')');

  {
    After adding the module, register a notifier to check for changes on the file
    and be able to ask if the file should be added to the SVN.
  }
  ModInfo := FProject.FindModuleInfo(AFileName);
  if (ModInfo <> nil) then
  begin
    Module := ModInfo.OpenModule;
    ModuleNotifierList.AddObject(AFileName, TModuleNotifier.Create(AFileName, Module));
  end;
end;

procedure TProjectNotifier.ModuleRemoved(const AFileName: string);
var
  Cmd: string;
  Idx: Integer;
  ModuleNotifier: TModuleNotifier;
begin
  WriteDebug('TProjectNotifier.ModuleRemoved (' + AFileName + ')');

  // If a module is removed from the project also remove the module notifier
  if (ModuleNotifierList.Find(AFileName, Idx)) then
  begin
    WriteDebug('Index ' + IntToStr(Idx));
    
    ModuleNotifier := TModuleNotifier(ModuleNotifierList.Objects[Idx]);
    ModuleNotifierList.Delete(Idx);
    ModuleNotifier.RemoveBindings;
  end;

  if (MessageDlg(Format(GetString(29), [ExtractFileName(AFileName)]), mtConfirmation, [mbYes,mbNo], 0) <> mrYes) then
    Exit;

  Cmd := '/command:remove /notempfile /path:' + AnsiQuotedStr(GetFilesForCmd(FProject, AFileName), '"');

  TTortoiseSVN.TSVNExec(Cmd);
end;

{ TModuleNotifier }

procedure TModuleNotifier.AfterSave;
var
  I: Integer;
  Cmd: string;
  FileList: TStringList;
begin
  if (MessageDlg(Format(GetString(28), [ExtractFileName(_Filename)]), mtConfirmation, [mbYes,mbNo], 0) <> mrYes) then
  begin
    {
      Always remove notifier after asking for adding the file and don't ask
      every time a file is saved.
    }
    RemoveBindings;

    Exit;
  end;

  Cmd := '';
  FileList := TStringList.Create;
  try
    GetModuleFiles(FileList, _Module);

    for I := 0 to FileList.Count - 1 do
    begin
      Cmd := Cmd + FileList[I];
      if (I < FileList.Count - 1) then
        Cmd := Cmd + '*';
    end;
  finally
    FileList.Free;
  end;

  Cmd := '/command:add /notempfile /path:' + AnsiQuotedStr(Cmd, '"');

  TTortoiseSVN.TSVNExec(Cmd);

  RemoveBindings;
end;

constructor TModuleNotifier.Create(Filename: string; Module: IOTAModule);
begin
  inherited Create;

  _Filename := Filename;
  _Module := Module;
  _Notifier := _Module.AddNotifier(Self);
end;

destructor TModuleNotifier.Destroy;
begin
  WriteDebug('TModuleNotifier.Destroy (' + _Module.FileName + ')');
  RemoveBindings;

  inherited Destroy;
end;

procedure TModuleNotifier.Destroyed;
begin
  WriteDebug('TModuleNotifier.Destroyed');
  RemoveBindings;

  inherited;
end;

procedure TModuleNotifier.RemoveBindings;
var
  Notifier: Integer;
begin
  if (_Module = nil) then
  begin
    _Notifier := -1;
    Exit;
  end;

  WriteDebug('TModuleNotifier.RemoveBindings (' + _Module.FileName + ')');

  Notifier := _Notifier;
  _Notifier := -1;

  try
    if (Notifier <> -1) then
    begin
      WriteDebug('Removing Notifier ' + IntToStr(Notifier));
      _Module.RemoveNotifier(Notifier);
    end;
  except
  end;

  WriteDebug('TModuleNotifier.RemoveBindings :: done');
end;

{ TProjectMenuTimer }

constructor TProjectMenuTimer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  Self.OnTimer := Self.TimerTick;
  Self.Interval := 1;
  Self.Enabled := True;
end;

procedure TProjectMenuTimer.TimerTick(Sender: TObject);
var
  I: Integer;
  Item: TMenuItem;
begin
  Self.Enabled := False;

  if (Owner is TMenuItem) then
  begin
    for I := 0 to TMenuItem(Owner).Count - 1 do
    begin
      Item := TMenuItem(Owner).Items[I];
      if (Item.Tag = SVN_DIFF) or
         (Item.Tag = SVN_LOG_FILE) or
         (Item.Tag = SVN_EDIT_CONFLICT) or
         (Item.Tag = SVN_CONFLICT_OK) then
      begin
        if (Item.ImageIndex = -1) and
           (Item.GetImageList <> nil) then
        begin
          if (ImgIdx[Item.Tag] = -1) then
            ImgIdx[Item.Tag] := Item.GetImageList.AddMasked(Bitmaps[Item.Tag], clBlack);
          Item.ImageIndex := ImgIdx[Item.Tag];
        end;
      end;
    end;
  end;

  TortoiseSVN.ProjectMenuTimer.Free;
  TortoiseSVN.ProjectMenuTimer := nil;
end;

{ TEditorNotifier }

procedure TEditorNotifier.AfterSave;
var
  Idx: Integer;
  I: Integer;
begin
  // If a file (*.pas) is saved, the corresponding files (*.dfm) are also saved
  // so it's safe to remove them from the list 
  for I := 0 to _Editor.Module.ModuleFileCount - 1 do
  begin
    if (ModifiedFiles.Find(_Editor.Module.ModuleFileEditors[I].FileName, Idx)) then
      ModifiedFiles.Delete(Idx);
  end;
end;

constructor TEditorNotifier.Create(const Editor: IOTAEditor);
begin
  inherited Create;

  _Editor := Editor;
  _Opened := True;
  _Notifier := _Editor.AddNotifier(Self as IOTAEditorNotifier);
end;

destructor TEditorNotifier.Destroy;
begin
  WriteDebug('TEditorNotifier.Destroy (' + _Editor.FileName + ')');
  RemoveBindings;

  inherited;
end;

procedure TEditorNotifier.Destroyed;
begin
  WriteDebug('TEditorNotifier.Destroyed (' + _Editor.FileName + ')');
  RemoveBindings;

  inherited;
end;

procedure TEditorNotifier.Modified;
begin
  if (ModifiedFiles.IndexOf(_Editor.FileName) = -1) then
    ModifiedFiles.Add(_Editor.FileName);
end;

procedure TEditorNotifier.RemoveBindings;
var
  Notifier: Integer;
begin
  WriteDebug('TEditorNotifier.RemoveBindings (' + _Editor.FileName + ')');
  
  Notifier := _Notifier;
  _Notifier := -1;

  if (Notifier <> -1) then
  begin
    try
      WriteDebug('Removing Notifier ' + IntToStr(Notifier));
      _Editor.RemoveNotifier(Notifier);
    except
    end;
  end;

  WriteDebug('TEditorNotifier.RemoveBindings :: done');
end;

procedure TEditorNotifier.ViewActivated(const View: IOTAEditView);
begin
  // not used
end;

procedure TEditorNotifier.ViewNotification(const View: IOTAEditView;
  Operation: TOperation);
begin
  {
    It can happen that no view is reported while registering the popup the first
    time so we need to check the view notification and add the popup afterwards.
  }
  if (not _Opened) and (Operation = opInsert) then
  begin
    _Opened := True;
    TIdeNotifier.RegisterPopup(View);
  end;
end;

initialization
  WriteDebug('initialization ' + DateTimeToStr(Now));
  NotifierList := TStringList.Create;
  NotifierList.Sorted := True;
  EditorNotifierList := TStringList.Create;
  EditorNotifierList.Sorted := True;
  ModifiedFiles := TStringList.Create;
  ModifiedFiles.Sorted := True;
  ModuleNotifierList := TStringList.Create;
  ModuleNotifierList.Sorted := True;

finalization
  WriteDebug('finalization ' + DateTimeToStr(Now));

  try
    WriteDebug('Should I remove the MenuCreatorNotifier?');
    if (MenuCreatorNotifier <> -1) then
    begin
      WriteDebug('Yes, I should!');
      (BorlandIDEServices as IOTAProjectManager).RemoveMenuCreatorNotifier(MenuCreatorNotifier);
    end;
  except
  end;

  try
    RemoveIDENotifier;
  except
  end;

  try
    FinalizeNotifiers;
  except
  end;

  try
    FinalizeEditorNotifiers;
  except
  end;

  try
    WriteDebug('FreeAndNil(ModifiedFiles)');
    FreeAndNil(ModifiedFiles);
  except
  end;

  try
    WriteDebug('FreeAndNil(ModuleNotifierList)');
    FreeAndNil(ModuleNotifierList);
  except
  end;

  try
    WriteDebug('Should I remove the EditMenuItem?');
    if (EditPopup <> nil) and
       (EditMenuItem <> nil) and
       (EditPopup.Items.IndexOf(EditMenuItem) > -1) then
    begin
      WriteDebug('Yes, I should!');
      EditPopup.Items.Remove(EditMenuItem);
      EditPopup := nil;
    end;
  except
  end;

  try
    WriteDebug('Should I free the EditMenuItem?');
    if (EditMenuItem <> nil) then
    begin
      WriteDebug('Yes, I should!');
      EditMenuItem.Free;
      EditMenuItem := nil;
    end;
  except
  end;
end.

