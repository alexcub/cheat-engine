unit d3dhookUnit;
{
This unit will inject the d3d hook dll into the target process and hook the
apropriate functions.
A shared object will be used for communicating states and data
}

{$mode delphi}

interface

uses
  windows, Classes, SysUtils, sharedMemory, forms, graphics, cefuncproc,
  newkernelhandler, controls, Clipbrd, strutils, LuaHandler, RemoteMemoryManager;

type
  TCEMessage=packed record
    uMsg: DWORD;
    wParam: UINT64;
    lParam: UINT64;
    character: DWORD;
  end;

  TTextureEntry=packed record
    AddressOfTexture: UINT64;
    AddressOfFontmap: UINT64;
    size: integer;
    hasBeenUpdated: integer;
  end;

  TTextureEntryArray=Array [0..1000] of TTextureEntry;
  PTextureEntryArray=^TTextureEntryArray;

  type TRenderCommandEnum=(rcEndOfCommandlist=0, //Stop going through the list
  			   rcIgnored=1,  //Ignore (Being updated)
  			   rcDrawSprite=2,		//Render the sprite at the given position
  			   rcDrawFont=3	);		//Render some text at the given coordinates. The string is located at  "addressoftext"

  TSpriteCommand=packed record
    width: integer;
    height: integer;
    textureid: integer;
  end;

  TFontCommand=packed record
    addressoftext: UINT64;
    fontid: integer;
  end;

  TRenderCommand=packed record
    command: integer;
    x: single;
    y: single;
    alphablend: single;
    case TRenderCommandEnum of
      rcDrawSprite: (Sprite: TSpriteCommand);
      rcDrawFont: (Font: TFontCommand);
  end;
  PRenderCommand=^TRenderCommand;

  TRenderCommandarray=array [0..100] of TRenderCommand;
  PRenderCommandArray=^TRenderCommandArray;


  TD3DHookShared=packed record
    cheatenginedir: array [0..255] of char;
    dxgi_present: UINT64;
    dxgi_resizebuffers: UINT64;
    d3d9_present: UINT64;
    d3d9_reset: UINT64;

    d3d9_drawprimitive: UINT64;
    d3d9_drawindexedprimitive: UINT64;
    d3d9_drawprimitiveup: UINT64;
    d3d9_drawindexedprimitiveup: UINT64;
    d3d9_drawrectpatch: UINT64;
    d3d9_drawtripatch: UINT64;

    d3d10_drawindexed: UINT64;
    d3d10_draw: UINT64;
    d3d10_drawindexedinstanced: UINT64;
    d3d10_drawinstanced: UINT64;
    d3d10_drawauto: UINT64;

    d3d11_drawindexed: UINT64;
    d3d11_draw: UINT64;
    d3d11_drawindexedinstanced: UINT64;
    d3d11_drawinstanced: UINT64;
    d3d11_drawauto: UINT64;


    dxgi_newpresent: UINT64;
    dxgi_newresizebuffers: UINT64;
    d3d9_newpresent: UINT64;
    d3d9_newreset: UINT64;

    d3d9_newdrawprimitive: UINT64;
    d3d9_newdrawindexedprimitive: UINT64;
    d3d9_newdrawprimitiveup: UINT64;
    d3d9_newdrawindexedprimitiveup: UINT64;
    d3d9_newdrawrectpatch: UINT64;
    d3d9_newdrawtripatch: UINT64;

    d3d10_newdrawindexed: UINT64;
    d3d10_newdraw: UINT64;
    d3d10_newdrawindexedinstanced: UINT64;
    d3d10_newdrawinstanced: UINT64;
    d3d10_newdrawauto: UINT64;

    d3d11_newdrawindexed: UINT64;
    d3d11_newdraw: UINT64;
    d3d11_newdrawindexedinstanced: UINT64;
    d3d11_newdrawinstanced: UINT64;
    d3d11_newdrawauto: UINT64;


    dxgi_originalpresent: UINT64;
    dxgi_originalresizebuffers: UINT64;
    d3d9_originalpresent: UINT64;
    d3d9_originalreset: UINT64;

    d3d9_originaldrawprimitive: UINT64;
    d3d9_originaldrawindexedprimitive: UINT64;
    d3d9_originaldrawprimitiveup: UINT64;
    d3d9_originaldrawindexedprimitiveup: UINT64;
    d3d9_originaldrawrectpatch: UINT64;
    d3d9_originaldrawtripatch: UINT64;

    d3d10_originaldrawindexed: UINT64;
    d3d10_originaldraw: UINT64;
    d3d10_originaldrawindexedinstanced: UINT64;
    d3d10_originaldrawinstanced: UINT64;
    d3d10_originaldrawauto: UINT64;

    d3d11_originaldrawindexed: UINT64;
    d3d11_originaldraw: UINT64;
    d3d11_originaldrawindexedinstanced: UINT64;
    d3d11_originaldrawinstanced: UINT64;
    d3d11_originaldrawauto: UINT64;


    wireframe: integer;
    disabledzbuffer: integer;

    hookwnd: integer;
    clipmouseinwindow: integer;

    clickedoverlay: integer;
    clickedx: integer;
    clickedy: integer;

    console: packed record
      hasconsole: integer;
      consolevisible: integer;
      consolekey: dword;
      overlayid: integer;
      cursorid: integer;
      lastmessage: TCEMessage;

    end;

    lastHwnd: DWORD;
    texturelistHasUpdate: integer; //If 1 this means that CE might be waiting for the HasHandledTextureUpdate event (if it is a high priority update)
    textureCount: integer;
    texturelist: UINT64 ; //offset into texturelist based on the start of the shared object (once setup, this does not change)
    TextureLock: UINT64 ; //target process handle
    commandListLock: UINT64;  //lockinforder: FIRST commandlist, THEN texturelist.
    useCommandListLock: integer;

    hasOnKey: integer;


    //followed by the rendercommands


  end;
  PD3DHookShared=^TD3DHookShared;



type
  TD3DHook_RenderObject=class;
  TD3DClickEvent=procedure(renderobject: TObject; x,y: integer) of object;
  TD3DKeyDownEvent=function(VirtualKey: dword; char: pchar): boolean of object;

  TD3DHook=class;
  TD3DHook_Texture=class;
  TD3DHook_Sprite=class;
  TD3DHook_Fontmap=class;
  TD3DHook_TextContainer=class;

  TD3DMessageHandler=class(tthread)
  private
    owner: TD3DHook;
    rendercommandid, x,y: integer; //clicked overlay

    lastmessage: TCEMessage;



    console: record
      log: Tstringlist;
      cursorpos: integer;

      backgroundtexture: TD3DHook_Texture;
      background: TD3DHook_Sprite;
      cursortexture: TD3DHook_Texture;
      cursor: TD3DHook_sprite;
      seperator: TD3dhook_sprite; //horizontal line splitting commandline from output
      fontmap: TD3DHook_Fontmap;
      output: TD3DHook_textcontainer; //history/output
      commandline: TD3DHook_TextContainer; //commandline
    end;
    procedure setConsoleCursorPos;


    procedure doclick;
    procedure dokeyboard;
  public
    procedure execute; override;
  end;


  TD3DHook_Texture=class(TObject)
  private
    resource: ptruint; //address where the current resource is located
  protected
    id: integer;
    owner: TD3DHook;
    fheight: integer;
    fwidth: integer;
  public
    function getID: integer;
   {

    procedure LoadTextureFromFile(filename: string);

    constructor Create(filename: string); overload;  }
    procedure LoadTextureByPicture(picture: TPicture);
    constructor Create(owner: TD3DHook; picture: TPicture);
    constructor Create(owner: TD3DHook);
    destructor destroy; override;

    property height: integer read fheight;
    property width: integer read fwidth;
  end;

  TD3DHook_FontMap=class(TD3DHook_Texture)
  private
    fontmapdata: ptruint;
    localfontmapcopy: TMemorystream; //used by calculateFontwidth
  public
    function calculateFontWidth(s:string): integer;
    procedure ChangeFont(font: TFont);
    constructor Create(owner: TD3DHook; font: TFont);
    destructor destroy; override;
  end;

  TD3DHook_RenderObject=class(TObject)
  private
    fx: single;
    fy: single;
    falphablend: single;
    fvisible: boolean;
    procedure setX(v: single);
    procedure setY(v: single);
    procedure setAlphaBlend(v: single);
    procedure setVisible(state: boolean);
    procedure setZOrder(newpos: integer);
  protected
    owner: TD3DHook;
    updatecount: integer;
  public
    function getIndex: integer;
    procedure beginUpdate;
    procedure endUpdate;
    procedure UpdateRenderCommand; virtual; abstract;

    destructor destroy; override;
    constructor create(owner: TD3DHook);

  published
    property zOrder: integer read getIndex write setZOrder;
    property alphaBlend: single read falphablend write setAlphablend;
    property x: single read fx write setX;
    property y: single read fy write setY;
    property visible: boolean read fVisible write setVisible;
  end;

  TD3Dhook_TextContainer=class(TD3DHook_RenderObject)   //class for rendering text
  private
    maxTextLength: integer;
    AddressOfText: QWORD;
    fFontMap: TD3DHook_FontMap;
    fText: string;

    addressChangedThisUpdate: boolean;
    oldAddressOfText: QWORD;
  private
    procedure setFontMap(fm: TD3DHook_FontMap);
    procedure setText(s: string);
  public
    procedure UpdateRenderCommand; override;


    destructor destroy; override;
    constructor create(owner: TD3DHook; fontmap: TD3DHook_FontMap; x,y: single; text: string; minsize: integer=0);
  published
    property FontMap: TD3DHook_FontMap read fFontMap write setFontMap;
    property Text: String read fText write setText;
  end;

  TD3DHook_Sprite=class(TD3DHook_RenderObject)     //clas for rendering textures
  private
    ftexture: TD3DHook_Texture;
    fwidth: integer;
    fheight: integer;


    procedure setTexture(s: TD3DHook_Texture);

    procedure setWidth(v: integer);
    procedure setHeight(v: integer);

  public

    procedure UpdateRenderCommand; override;

    constructor create(owner: TD3DHook; texture: TD3DHook_Texture);
  published
    property width: integer read fWidth write setWidth;
    property height: integer read fHeight write setHeight;
    property texture: TD3DHook_Texture read ftexture write setTexture;
  end;


  TD3DHook=class(TObject)
  private
    fonKeyDown: TD3DKeyDownEvent;
    sharename: string;
    shared: PD3DHookShared; //local address of the D3DHookShared structure

    tea: PTextureEntryArray;


    fmhandle: THandle;

    textures: TList;
    commandlist: TList; //collection of pointer to objects used for lookup and id management.  1-on-1 relation to the renderCommands list
    renderCommandList: PRenderCommandArray;

    isupdating: integer; //update counter for the texture list
    isupdatingCL: integer; //update counter for the command list

    maxsize: integer;
    fprocessid: dword;

    hasclickevent: THandle;
    hashandledclickevent: THandle;

    haskeyboardevent: THandle;        //todo: combine into one "HasMessage" event, but for now, to make sure I don't break anything, this method...
    hashandledkeyboardevent: THandle;

    texturelock: THandle;
    CommandListLock: THandle;

    messagehandler: TD3DMessageHandler;



    memman: TRemoteMemoryManager;

    procedure setOnKeyDown(s: TD3DKeyDownEvent);
  public
    onclick: TD3DClickEvent;

    procedure beginTextureUpdate;
    procedure endTextureUpdate;

    procedure beginCommandListUpdate;
    procedure endCommandListUpdate;

    function createTexture(f: string): TD3DHook_Texture; overload;
    function createTexture(p: TPicture): TD3DHook_Texture; overload;
    function createSprite(texture: TD3DHook_Texture): TD3DHook_Sprite;

    function createFontMap(f: TFont): TD3DHook_FontMap;
    function createTextContainer(fontmap: TD3DHook_FontMap; x,y: single; text: string): TD3Dhook_TextContainer;


    procedure setDisabledZBuffer(state: boolean);
    procedure setWireframeMode(state: boolean);
    procedure setMouseClip(state: boolean);

    function getWidth: integer;
    function getHeight: integer;

    procedure setCommandListLockFeature(state: boolean);


    procedure enableConsole(virtualkey: DWORD);

    constructor create(size: integer; hookhwnd: boolean=true);
    destructor destroy; override;
    property processid: dword read fprocessid;
    property onKeyDown: TD3DKeyDownEvent read fonKeyDown write setOnKeyDown;
  end;

var D3DHook: TD3DHook;

function safed3dhook(size: integer=16*1024*1024; hookwindow: boolean=true): TD3DHook;

implementation

uses frmautoinjectunit, autoassembler, MainUnit;

procedure TD3DMessageHandler.setConsoleCursorPos;
var s: string;
begin
  if console.cursor<>nil then
  begin
    console.cursor.y:=console.commandline.y;

    s:=copy(console.commandline.Text,1, console.cursorpos);

    console.cursor.x:=console.fontmap.calculateFontWidth(s);
  end;
end;

procedure TD3DMessageHandler.dokeyboard;
var virtualkey: dword;
    scancode: dword;

    c,c2: string;
    s: pchar;
    old: tstrings;
    p: tpicture;
    f: tfont;
    maxlines: integer;
    currentlines: integer;
    i: integer;
    l: string;
begin
  //check the size of the window. If it's changed, reinitialize the consoleoverlay

  owner.shared.console.lastmessage.uMsg:=0; //don't handle the keypress in the target process


  if assigned(owner.onkeydown) then
  begin
    if owner.onkeydown(lastmessage.wParam, pchar(@lastmessage.character)) then
      owner.shared.console.lastmessage.uMsg:=1; //if it returns true, let it go through

  end;

  if (owner.shared.console.hasconsole=0) or (owner.shared.console.consolevisible=0) then exit;

  //just create or show the console
  if console.background=nil then
  begin
    owner.beginTextureUpdate;

    try
      p:=tpicture.Create;
      p.png.canvas.brush.color:=clBlack;
      p.png.width:=1;
      p.png.height:=1;

      console.backgroundtexture:=TD3DHook_Texture.Create(owner, p);
      p.free;

      console.background:=TD3DHook_Sprite.create(owner, console.backgroundtexture);


      console.background.width:=-1; //full width
      console.background.height:=owner.getHeight div 2;
      console.background.x:=0;
      console.background.y:=owner.getHeight div 2;
      console.background.alphaBlend:=0.80;

      p:=tpicture.Create;
      p.png.canvas.brush.color:=clWhite;
      p.png.width:=1;
      p.png.height:=1;
      p.png.Canvas.Pixels[0,0]:=clWhite;
      console.cursortexture:=TD3DHook_Texture.Create(owner, p);
      p.free;

      console.cursor:=TD3DHook_sprite.create(owner, console.cursortexture);


      f:=tfont.create;
      f.Assign(mainform.Font);
      f.color:=clWhite;
      f.Size:=f.size*2;

      console.fontmap:=TD3DHook_FontMap.Create(owner, f);
      console.commandline:=TD3Dhook_TextContainer.create(owner, console.fontmap, 0, owner.getHeight-console.fontmap.height,'',256);

      console.seperator:=TD3DHook_sprite.create(owner, console.cursortexture); //same color
      console.seperator.x:=0;
      console.seperator.y:=owner.getHeight-console.fontmap.height;
      console.seperator.height:=1;
      console.seperator.width:=-1; //full width


      console.output:=TD3Dhook_TextContainer.create(owner, console.fontmap, 0, owner.getHeight div 2,'',8192);


      console.cursor.width:=3;
      console.cursor.height:=console.fontmap.height;
      //
    finally
      owner.endTextureUpdate;
    end;
  end;


  setConsoleCursorPos;

  if lastmessage.uMsg=$ffffffff then
  begin
    console.background.visible:=true;
    console.seperator.visible:=true;
    console.cursor.visible:=true;
    console.output.visible:=true;
    console.commandline.visible:=true;
    exit; //nothing else to do
  end;

  if lastmessage.uMsg=$fffffffe then
  begin
    console.background.visible:=false;
    console.seperator.visible:=false;
    console.cursor.visible:=false;
    console.output.visible:=false;
    console.commandline.visible:=false;
    exit;
  end;


  //handle the key
  virtualkey:=lastmessage.wParam;
  scancode:=(lastmessage.lparam shr 16) and $FF;

  owner.beginTextureUpdate;

  //handle keys like delete, backspace, etc...
  case virtualkey of
    VK_RETURN:
    begin
      //execute the command
      console.log.add(console.commandline.Text);

      LuaCS.enter;
      old:=lua_oldprintoutput;
      lua_setPrintOutput(console.log);
      lua_dostring(LuaVM, pchar(console.commandline.Text));
      lua_setPrintOutput(old);
      luacs.Leave;

      //calculate the max number of lines
      maxlines:=trunc((console.seperator.y-console.background.y) / console.output.FontMap.height);
      currentlines:=0;
      l:='';
      for i:=max(0, console.log.Count-maxlines) to console.log.Count-1 do
      begin
        l:=l+console.log[i]+#13#10;

        inc(currentlines);
        if (currentlines>=maxlines) then break;
      end;


      console.output.y:=console.seperator.y-(currentlines*console.output.FontMap.height);
      console.output.Text:=l;

      console.commandline.Text:='';
      console.cursorpos:=0;
    end;
    VK_LEFT:
    begin
      if console.cursorpos>0 then
        dec(console.cursorpos);
    end;

    VK_RIGHT:
    begin
      if console.cursorpos<length(console.commandline.Text) then
        inc(console.cursorpos);
    end;
    VK_BACK:
    begin
      //delete the character before the cursorpos
      if console.cursorpos>0 then
      begin
        c:=copy(console.commandline.text, 1, console.cursorpos-1);
        c2:=copy(console.commandline.text, console.cursorpos+1, length(console.commandline.Text));
        console.commandline.text:=c+c2;
        dec(console.cursorpos);
      end;
    end;

    VK_DELETE:
    begin
      //delete the character after the current cursor
      c:=copy(console.commandline.text, 1, console.cursorpos);
      c2:=copy(console.commandline.text, console.cursorpos+2, length(console.commandline.text));
      console.commandline.text:=c+c2;
    end
    else
    begin
      //not a control key, check if it's a character
      if lastmessage.character<>0 then
      begin
        //it's a character
        s:=@lastmessage.character;

        c:=copy(console.commandline.text, 1, console.cursorpos);
        c2:=copy(console.commandline.text, console.cursorpos+1, length(console.commandline.text));


        console.commandline.text:=c+s+c2;

        inc(console.cursorpos);
      end;
    end;
  end;


  setConsoleCursorPos;

  owner.endTextureUpdate;

end;

procedure TD3DMessageHandler.doclick;
begin
  if assigned(owner.onclick) then
    owner.onclick(TD3DHook_RenderObject(owner.commandlist[rendercommandid]), x,y);
end;

procedure TD3DMessageHandler.execute;
var eventlist: array of THandle;
    r: dword;

    cursor: boolean;
    cursorstart: dword;
begin
  cursorstart:=gettickcount;
  console.log:=tstringlist.create;
  console.cursorpos:=0;

  setlength(eventlist,2);
  eventlist[0]:=owner.hasclickevent;
  eventlist[1]:=owner.haskeyboardevent;

  while (not terminated) do
  begin
    r:=WaitForMultipleObjects(2, @eventlist[0], false, 100);
    case r of
      WAIT_OBJECT_0:
      begin
        //click event: quickly save the variables and tell the game to continue
        x:=owner.shared.clickedx;
        y:=owner.shared.clickedy;
        rendercommandid:=owner.shared.clickedoverlay;
        SetEvent(owner.hashandledclickevent);

        Synchronize(doclick);
      end;

      WAIT_OBJECT_0+1:
      begin
        //keyboard event
        lastmessage:=owner.shared.console.lastmessage;
        Synchronize(dokeyboard);
        SetEvent(owner.hashandledkeyboardevent);
        cursorstart:=GetTickCount;
      end;
    end;

    if (owner.shared.console.consolevisible=1) and (console.cursor<>nil) then  //toggle the cursor visible or invisible based on the current time and if a key was pressed (keep the cursor visible rigth after pressing a key, so reset the timerstart)
      console.cursor.visible:=(((GetTickCount-cursorstart) mod 1000)<500);

  end;

end;

//----------------------------D3DHook_RenderObject------------------------------

procedure TD3DHook_RenderObject.setAlphaBlend(v: single);
begin
  if falphablend=v then exit;

  BeginUpdate;
  falphablend:=v;
  endUpdate;
end;

procedure TD3DHook_RenderObject.setX(v: single);
begin
  if fx=v then exit;

  beginUpdate;
  fx:=v;
  endUpdate;
end;

procedure TD3DHook_RenderObject.setY(v: single);
begin
  if fy=v then exit;

  beginUpdate;
  fy:=v;
  endUpdate;
end;


procedure TD3DHook_RenderObject.setVisible(state: boolean);
begin
  if fvisible=state then exit; //no change, no update

  beginUpdate;
  fvisible:=state;
  endUpdate;
end;

procedure TD3DHook_RenderObject.setZOrder(newpos: integer);
var
  mypos: integer;
  replaced: TD3DHook_RenderObject;
begin
  //change the order of the commandlist
  mypos:=zorder;
  if (newpos<>mypos) and (newpos<owner.commandlist.count) then
  begin
    replaced:=TD3DHook_RenderObject(owner.commandlist[newpos]);

    owner.beginCommandListUpdate;

    owner.renderCommandList^[newpos].command:=integer(rcIgnored); //in case the locking option is not used. Will cause some flickering in the worst case
    owner.renderCommandList^[mypos].command:=integer(rcIgnored);

    owner.commandlist[newpos]:=self;
    owner.commandlist[mypos]:=replaced;

    //now update mine and the replaced one's rendercommand entry
    UpdateRenderCommand;
    if replaced<>nil then
      replaced.UpdateRenderCommand;

    owner.endCommandListUpdate;
  end;
end;

function TD3DHook_RenderObject.getIndex: integer;
begin
  result:=owner.commandlist.IndexOf(self);
end;

procedure TD3DHook_RenderObject.beginUpdate;
begin
  inc(updatecount);
end;

procedure TD3DHook_RenderObject.endUpdate;
begin
  if updatecount>0 then
    dec(updatecount);

  if updatecount=0 then
    UpdateRenderCommand;
end;

destructor TD3DHook_RenderObject.destroy;
var index: integer;
begin
  index:=getindex;
  owner.renderCommandList^[Index].command:=integer(rcIgnored);
  owner.commandlist[index]:=nil;

  inherited destroy;
end;

constructor TD3DHook_RenderObject.create(owner: TD3DHook);
begin
  self.owner:=owner;
  falphablend:=1;
  fvisible:=true;
  owner.commandlist.Add(self);
end;

//----------------------------D3DHook_TextContainer-----------------------------
procedure TD3Dhook_TextContainer.setText(s: string);
var
  x: dword;
  nul: byte;
begin
  BeginUpdate;

  fText:=s;
  if length(s)+1>maxTextLength then //+1 for 0 terminator
  begin
    if AddressOfText<>0 then //free the old block
      owner.memman.dealloc(AddressOfText);

    maxTextLength:=length(s)+16;
    AddressOfText:=owner.memman.alloc(maxTextLength);
  end;

  if s='' then
  begin
    nul:=0;
    WriteProcessMemory(processhandle, pointer(AddressOfText), @nul, 1, x);
  end
  else
    WriteProcessMemory(processhandle, pointer(AddressOfText), @s[1], length(s)+1, x); //just write

  endUpdate;
end;

procedure TD3Dhook_TextContainer.setFontMap(fm: TD3DHook_FontMap);
begin
  BeginUpdate;
  fFontMap:=fm;
  endUpdate;
end;

procedure TD3Dhook_TextContainer.UpdateRenderCommand;
var index: integer;
begin
  index:=getindex;
  owner.beginCommandListUpdate;

  if (index<>-1) and (fFontmap<>nil) and (fVisible) then
  begin
    if owner.renderCommandList^[index].command<>integer(rcDrawFont) then //something completly new
      owner.renderCommandList^[index].command:=integer(rcIgnored);

    owner.renderCommandList^[index].x:=x;
    owner.renderCommandList^[index].y:=y;
    owner.renderCommandList^[index].alphablend:=alphablend;
    owner.renderCommandList^[index].Font.fontid:=fFontmap.getID;
    owner.renderCommandList^[index].Font.addressoftext:=AddressOfText;

    owner.renderCommandList^[index].command:=integer(rcDrawFont);
  end
  else
    owner.renderCommandList^[index].command:=integer(rcIgnored);

  owner.endCommandListUpdate;
end;

destructor TD3Dhook_TextContainer.destroy;
begin
  if AddressOfText<>0 then
    owner.memman.dealloc(addressoftext);
  inherited destroy;
end;

constructor TD3Dhook_TextContainer.create(owner: TD3DHook; fontmap: TD3DHook_FontMap; x,y: single; text: string; minsize: integer=0);
begin
  inherited create(owner);

  beginupdate;

  if minsize<>0 then
  begin
    maxTextLength:=minsize;
    AddressOfText:=owner.memman.alloc(maxTextLength);
  end;

  self.x:=x;
  self.y:=y;
  self.FontMap:=fontmap;
  self.text:=text;

  endUpdate;
end;

//-------------------------------D3DHook_Sprite---------------------------------
procedure TD3DHook_Sprite.setWidth(v: integer);
begin
  beginUpdate;
  fwidth:=v;
  endUpdate;
end;

procedure TD3DHook_Sprite.setHeight(v: integer);
begin
  beginUpdate;
  fheight:=v;
  endUpdate;
end;

procedure TD3DHook_Sprite.setTexture(s: TD3DHook_Texture);
begin
  BeginUpdate;
  ftexture:=s;
  width:=s.width;
  height:=s.height;
  EndUpdate;
end;

procedure TD3DHook_Sprite.UpdateRenderCommand;
var index: integer;
begin
  index:=getindex;

  owner.beginCommandListUpdate;

  if (index<>-1) and (texture<>nil) and (fVisible) then
  begin
    if owner.renderCommandList^[index].command<>integer(rcDrawSprite) then //something completly new
      owner.renderCommandList^[index].command:=integer(rcIgnored);

    owner.renderCommandList^[index].x:=x;
    owner.renderCommandList^[index].y:=y;
    owner.renderCommandList^[index].alphablend:=alphablend;
    owner.renderCommandList^[index].Sprite.width:=width;
    owner.renderCommandList^[index].Sprite.height:=height;
    owner.renderCommandList^[index].Sprite.textureid:=texture.getID;
    owner.renderCommandList^[index].command:=integer(rcDrawSprite);
  end
  else
    owner.renderCommandList^[index].command:=integer(rcIgnored);



  owner.endCommandListUpdate;
end;

constructor TD3DHook_Sprite.create(owner: TD3DHook; texture: TD3DHook_Texture);
begin
  inherited create(owner);
  beginupdate;


  setTexture(texture);
  endUpdate;
end;

//-------------------------------d3dhook_font-----------------------------------

function TD3DHook_FontMap.calculateFontWidth(s:string): integer;
var cwa: PWordarray;
  i: integer;
  c: byte;
begin
  result:=0;
  cwa:=localfontmapcopy.memory;
  for i:=1 to length(s) do
  begin
    c:=ord(s[i]);
    if c in [32..127] then
      inc(result,cwa[c-32+1]);
  end;
end;

procedure TD3DHook_FontMap.ChangeFont(font: TFont);
var s: string;
    i: integer;
    charpos: integer;

    p: TPicture;


    charwidth: word; //65535 if the max size of one character

    newblock: pointer;
    x: dword;
begin
  p:=TPicture.Create;
  p.PNG.PixelFormat:=pf32bit;
  p.png.canvas.font:=font;
  p.png.canvas.brush.color:=InvertColor(font.color);
  p.png.Transparent:=true;
  p.png.TransparentColor:=p.png.canvas.brush.color;
  p.png.width:=100;
  p.png.height:=100; //initial setup

  //create a fontmap picture with this font and set that as the texture
  //also fill in the fontmap layout

  s:='';
  for i:=32 to 127 do
    s:=s+chr(i);


  fheight:=p.png.canvas.GetTextHeight(s); //get the max height


  //calculate the width based on a per character rendering. (perhaps the whole string might have been using a half pixel at some spots...)
  fwidth:=0;
  for i:=32 to 127 do
    fwidth:=fwidth+p.png.canvas.GetTextWidth(chr(i));


  //setup the image

  p.png.Width:=fwidth;
  p.png.height:=fheight;

  if localfontmapcopy<>nil then
    freeandnil(localfontmapcopy);

  localfontmapcopy:=tmemorystream.create;  //buffer to obtain the fontmap data
  localfontmapcopy.WriteBuffer(fheight, sizeof(word)); //2 bytes for the height of all characters

  //now fill it in
  charpos:=0;
  for i:=32 to 127 do
  begin
    p.PNG.canvas.TextOut(charpos, 0, chr(i));
    charwidth:=p.png.Canvas.GetTextWidth(chr(i));
    localfontmapcopy.WriteBuffer(charwidth,2);
    charpos:=charpos+charwidth;
  end;

  newblock:=pointer(owner.memman.alloc(localfontmapcopy.size));


  if newblock<>nil then
  begin
    if WriteProcessMemory(processhandle, newblock, localfontmapcopy.memory, localfontmapcopy.size, x) then
    begin
      owner.beginTextureUpdate;

      //set the font state

      owner.tea[id].AddressOfFontmap:=qword(newblock);
      owner.tea[id].hasBeenUpdated:=1;

      //free old block if possible
      if (resource<>0) then
        owner.memman.dealloc(fontmapdata);


      LoadTextureByPicture(p);
      owner.endTextureUpdate;

      fontmapdata:=qword(newblock);
    end;
  end;

  p.SaveToFile('c:\bla.png');
end;

destructor TD3DHook_FontMap.destroy;
begin
  if fontmapdata<>0 then
    owner.memman.dealloc(fontmapdata);

  inherited destroy;
end;

constructor TD3DHook_FontMap.Create(owner: TD3DHook; font: TFont);
begin
  inherited create(owner);
  ChangeFont(font);

end;


//-------------------------------d3dhook_texture--------------------------------
procedure TD3DHook_Texture.LoadTextureByPicture(picture: TPicture);
var m: tmemorystream;
    newblock: pointer;
    x: dword;
    msp: pointer;
    s: integer;
begin
  m:=TMemoryStream.create;
  picture.PNG.SaveToStream(m);

  owner.beginTextureUpdate;

  newblock:=pointer(owner.memman.alloc(m.size));
  if newblock<>nil then
  begin
    msp:=m.Memory;
    s:=m.size;
    if WriteProcessMemory(processhandle, newblock, m.memory, m.size, x) then
    begin
      owner.tea[id].AddressOfTexture:=qword(newblock);
      owner.tea[id].Size:=m.size;
      owner.tea[id].hasBeenUpdated:=1;

      //free old block if possible
      if (resource<>0) then
        owner.memman.dealloc(resource);

      fheight:=picture.Height;
      fwidth:=picture.Width;
    end;

    resource:=qword(newblock);
  end;

  m.free;

  owner.endTextureUpdate;
end;

function TD3DHook_Texture.getID: integer;
begin
  result:=id;
end;

destructor TD3DHook_Texture.destroy;
begin
  owner.beginTextureUpdate;

  owner.tea[id].AddressOfTexture:=0;
  owner.tea[id].hasBeenUpdated:=1; //marks for deletion

  if resource<>0 then
    owner.memman.dealloc(resource);

  owner.textures[id]:=nil;
  owner.endTextureUpdate;
  inherited destroy;
end;

constructor TD3DHook_Texture.Create(owner: TD3DHook);
var i: integer;
begin
  self.owner:=owner;
  id:=-1;

  //find a empty slot, and if not found, add it instead
  for i:=0 to owner.textures.count-1 do
    if owner.textures[i]=nil then
    begin
      id:=i;
      owner.textures[id]:=self;
      break;
    end;

  if id=-1 then
    id:=owner.textures.add(self);
end;

constructor TD3DHook_Texture.Create(owner: TD3DHook; picture: TPicture);
var m: TMemoryStream;
begin
  create(owner);

  LoadTextureByPicture(picture);
end;



//----------------------------------D3dhook-------------------------------------

procedure TD3DHook.setOnKeyDown(s: TD3DKeyDownEvent);
begin
  if assigned(s) then
  begin
    fonKeyDown:=s;
    shared.hasOnKey:=1;
  end
  else
    shared.hasOnKey:=0;

end;

procedure TD3DHook.enableConsole(virtualkey: DWORD);
begin
  shared.console.hasconsole:=1;
  shared.console.consolekey:=virtualkey;
end;

procedure TD3DHook.setDisabledZBuffer(state: boolean);
begin
  if state then
    shared.disabledzbuffer:=1
  else
    shared.disabledzbuffer:=0;
end;

procedure TD3DHook.setWireframeMode(state: boolean);
begin
  if state then
    shared.wireframe:=1
  else
    shared.wireframe:=0;
end;

procedure TD3DHook.setMouseClip(state: boolean);
begin
  if state then
    shared.clipmouseinwindow:=1
  else
    shared.clipmouseinwindow:=0;
end;

function TD3DHook.getWidth: integer;
var x: trect;
begin
  if (shared<>nil) and (GetClientRect(shared.lastHwnd, x)) then
    result:=x.Right-x.left
  else
    result:=0;
end;

function TD3DHook.getHeight: integer;
var x: trect;
begin
  if (shared<>nil) and (GetClientRect(shared.lastHwnd, x)) then
    result:=x.bottom-x.top
  else
    result:=0;

end;

procedure TD3DHook.setCommandListLockFeature(state: boolean);
begin
  shared.useCommandListLock:=integer(state);
end;

procedure TD3DHook.beginCommandListUpdate;
begin
  if self=nil then
    raise exception.create('The d3dhook object has not been created yet');

  if isupdatingCL=0 then //start of an edit
    WaitForSingleObject(CommandListLock, INFINITE);  //obtain lock

  inc(isupdatingCL);
end;

procedure TD3DHook.endCommandListUpdate;
begin
  renderCommandList^[commandlist.count].command:=integer(rcEndOfCommandlist);

  if isupdatingCL>0 then
  begin
    dec(isupdatingCL);
    if isupdatingCL=0 then
      SetEvent(CommandListLock); //release the lock
  end;


end;

procedure TD3DHook.beginTextureUpdate;
begin
  if isupdating=0 then //start of an edit
  begin
    beginCommandListUpdate;
    WaitForSingleObject(TextureLock, INFINITE);  //obtain lock
  end;

  inc(isupdating);
end;

procedure TD3DHook.endTextureUpdate;
begin
  if isupdating>0 then
  begin
    dec(isupdating);
    if isupdating=0 then
    begin
      shared.textureCount:=textures.count;
      shared.texturelistHasUpdate:=1;

      SetEvent(TextureLock); //release the lock

      endCommandListUpdate;
    end;
  end;
end;


//++++++++++++++++++++++++++++++++++++++++++++++++++++++version 2
function TD3DHook.createFontMap(f: TFont): TD3DHook_FontMap;
begin
  beginTextureUpdate;
  result:=TD3DHook_FontMap.Create(self, f);
  endTextureUpdate;
end;

function TD3DHook.createTextContainer(fontmap: TD3DHook_FontMap; x,y: single; text: string): TD3Dhook_TextContainer;
begin
  beginCommandListUpdate;
  try
    result:=TD3Dhook_TextContainer.create(self, fontmap, x,y,text);
  finally
    endCommandListUpdate;
  end;
end;

function TD3DHook.createTexture(f: string): TD3DHook_Texture; overload;
var p: TPicture;
begin
  p:=tpicture.Create;
  beginTextureUpdate;
  try
    p.LoadFromFile(f);
    result:=TD3DHook_Texture.Create(self, p);
  finally
    p.free;
    endTextureUpdate;
  end;
end;

function TD3DHook.createTexture(p: TPicture): TD3DHook_Texture;
begin
  beginTextureUpdate;
  result:=TD3DHook_Texture.Create(self, p);
  endTextureUpdate;
end;

function TD3DHook.createSprite(texture: TD3DHook_Texture): TD3DHook_Sprite;
begin
  beginCommandListUpdate;
  result:=TD3DHook_Sprite.create(self, texture);
  endCommandListUpdate;
end;


destructor TD3DHook.Destroy;
begin
  if messagehandler<>nil then
  begin
    messagehandler.terminate;
    messagehandler.Free;
  end;


  UnmapViewOfFile(shared);
  closehandle(fmhandle);


  commandlist.free;
  textures.free;

  memman.free;
  inherited destroy;
end;

constructor TD3DHook.create(size: integer; hookhwnd: boolean=true);
var h: thandle;
    s: TStringList;
begin
  memman:=TRemoteMemoryManager.create;
  textures:=TList.create;
  commandlist:=TList.create;


  sharename:='CED3D_'+inttostr(processhandler.ProcessID);

  fprocessid:=processhandler.processid;
  maxsize:=size;

  createSharedMemory(sharename, sizeof(TD3DHookShared)+maxsize);

  fmhandle:=OpenFileMapping(FILE_MAP_EXECUTE or FILE_MAP_READ or FILE_MAP_WRITE, false, pchar(sharename));
  if fmhandle=0 then
    raise exception.create('D3DHook: Failure to open the shared memory object');

  shared:=MapViewOfFile(fmhandle,FILE_MAP_EXECUTE or FILE_MAP_READ or FILE_MAP_WRITE, 0,0,0 );

  if shared=nil then
    raise exception.create('D3DHook: Failure to map the shared memory object');

  ZeroMemory(shared, sizeof(TD3DHookShared));

  shared.texturelist:=sizeof(TD3DHookShared)+(maxsize div 2);
  shared.cheatenginedir:=CheatEngineDir;
  shared.useCommandListLock:=1;



  tea:=PTextureEntryArray(ptruint(shared)+shared.texturelist);
  renderCommandList:=PRenderCommandArray(ptruint(shared)+sizeof(TD3dHookShared));;

  if hookhwnd then
    shared.hookwnd:=1;

  h:=CreateEventA(nil, true, false, pchar(sharename+'_READY') );

  if (h<>0) then
  begin

    if hookhwnd then
    begin
      hasclickevent:=CreateEventA(nil, false, false, pchar(sharename+'_HASCLICK') );
      hashandledclickevent:=CreateEventA(nil, false, true, pchar(sharename+'_HANDLEDCLICK') );

      haskeyboardevent:=CreateEventA(nil, false, false, pchar(sharename+'_HASKEYBOARD') );
      hashandledkeyboardevent:=CreateEventA(nil, false, true, pchar(sharename+'_HANDLEDKEYBOARD') );


      messagehandler:=TD3DMessageHandler.Create(true);
      messagehandler.owner:=self;
      messagehandler.start;
    end;


    TextureLock:=CreateEventA(nil, false, true, nil);


    DuplicateHandle(GetCurrentProcess, TextureLock, processhandle, @shared.TextureLock,0, false,DUPLICATE_SAME_ACCESS);

    CommandListLock:=CreateEventA(nil, false, true, nil);
    DuplicateHandle(GetCurrentProcess, CommandListLock, processhandle, @shared.CommandListLock,0, false,DUPLICATE_SAME_ACCESS);


    //now inject the dll
    injectdll(cheatenginedir+'d3dhook.dll');

    //wait till the injection is done
    WaitForSingleObject(h, INFINITE);
    closehandle(h);

    //and hook the functions
    //(script: tstrings; address: string; addresstogoto: string; addresstostoreneworiginalfunction: string=''; nameextension:string='0');
    s:=tstringlist.create;
    try
      if shared.d3d9_present<>0 then
        generateAPIHookScript(s, inttohex(shared.d3d9_present,8), inttohex(shared.d3d9_newpresent,8),  inttohex(shared.d3d9_originalpresent,8), '0');

      if shared.d3d9_reset<>0 then
        generateAPIHookScript(s, inttohex(shared.d3d9_reset,8), inttohex(shared.d3d9_newreset,8),  inttohex(shared.d3d9_originalreset,8), '1');

      if shared.dxgi_present<>0 then
        generateAPIHookScript(s, inttohex(shared.dxgi_present,8), inttohex(shared.dxgi_newpresent,8),  inttohex(shared.dxgi_originalpresent,8), '2');

      if shared.d3d9_drawprimitive<>0 then
        generateAPIHookScript(s, inttohex(shared.d3d9_drawprimitive,8), inttohex(shared.d3d9_newdrawprimitive,8),  inttohex(shared.d3d9_originaldrawprimitive,8), '3');

      if shared.d3d9_drawindexedprimitive<>0 then
        generateAPIHookScript(s, inttohex(shared.d3d9_drawindexedprimitive,8), inttohex(shared.d3d9_newdrawindexedprimitive,8),  inttohex(shared.d3d9_originaldrawindexedprimitive,8), '4');

      if shared.d3d9_drawprimitiveup<>0 then
        generateAPIHookScript(s, inttohex(shared.d3d9_drawprimitiveup,8), inttohex(shared.d3d9_newdrawprimitiveup,8),  inttohex(shared.d3d9_originaldrawprimitiveup,8), '5');

      if shared.d3d9_drawindexedprimitiveup<>0 then
        generateAPIHookScript(s, inttohex(shared.d3d9_drawindexedprimitiveup,8), inttohex(shared.d3d9_newdrawindexedprimitiveup,8),  inttohex(shared.d3d9_originaldrawindexedprimitiveup,8), '6');

      if shared.d3d9_drawrectpatch<>0 then
        generateAPIHookScript(s, inttohex(shared.d3d9_drawrectpatch,8), inttohex(shared.d3d9_newdrawrectpatch,8),  inttohex(shared.d3d9_originaldrawrectpatch,8), '7');

      if shared.d3d9_drawtripatch<>0 then
        generateAPIHookScript(s, inttohex(shared.d3d9_drawtripatch,8), inttohex(shared.d3d9_newdrawtripatch,8),  inttohex(shared.d3d9_originaldrawtripatch,8), '8');


      if shared.d3d10_drawindexed<>0 then
        generateAPIHookScript(s, inttohex(shared.d3d10_drawindexed,8), inttohex(shared.d3d10_newdrawindexed,8),  inttohex(shared.d3d10_originaldrawindexed,8), '9');

      if shared.d3d10_draw<>0 then
        generateAPIHookScript(s, inttohex(shared.d3d10_draw,8), inttohex(shared.d3d10_newdraw,8),  inttohex(shared.d3d10_originaldraw,8), '10');

      if shared.d3d10_drawindexedinstanced<>0 then
        generateAPIHookScript(s, inttohex(shared.d3d10_drawindexedinstanced,8), inttohex(shared.d3d10_newdrawindexedinstanced,8),  inttohex(shared.d3d10_originaldrawindexedinstanced,8), '11');

      if shared.d3d10_drawinstanced<>0 then
        generateAPIHookScript(s, inttohex(shared.d3d10_drawinstanced,8), inttohex(shared.d3d10_newdrawinstanced,8),  inttohex(shared.d3d10_originaldrawinstanced,8), '12');

      if shared.d3d10_drawauto<>0 then
        generateAPIHookScript(s, inttohex(shared.d3d10_drawauto,8), inttohex(shared.d3d10_newdrawauto,8),  inttohex(shared.d3d10_originaldrawauto,8), '13');


      if shared.d3d11_drawindexed<>0 then
        generateAPIHookScript(s, inttohex(shared.d3d11_drawindexed,8), inttohex(shared.d3d11_newdrawindexed,8),  inttohex(shared.d3d11_originaldrawindexed,8), '14');

      if shared.d3d11_draw<>0 then
        generateAPIHookScript(s, inttohex(shared.d3d11_draw,8), inttohex(shared.d3d11_newdraw,8),  inttohex(shared.d3d11_originaldraw,8), '15');

      if shared.d3d11_drawindexedinstanced<>0 then
        generateAPIHookScript(s, inttohex(shared.d3d11_drawindexedinstanced,8), inttohex(shared.d3d11_newdrawindexedinstanced,8),  inttohex(shared.d3d11_originaldrawindexedinstanced,8), '16');

      if shared.d3d11_drawinstanced<>0 then
        generateAPIHookScript(s, inttohex(shared.d3d11_drawinstanced,8), inttohex(shared.d3d11_newdrawinstanced,8),  inttohex(shared.d3d11_originaldrawinstanced,8), '17');

      if shared.d3d11_drawauto<>0 then
        generateAPIHookScript(s, inttohex(shared.d3d11_drawauto,8), inttohex(shared.d3d11_newdrawauto,8),  inttohex(shared.d3d11_originaldrawauto,8), '18');

      if shared.dxgi_resizebuffers<>0 then
        generateAPIHookScript(s, inttohex(shared.dxgi_resizebuffers,8), inttohex(shared.dxgi_newresizebuffers,8),  inttohex(shared.dxgi_originalresizebuffers,8), '19');


      clipboard.AsText:=s.text;

      //if there is a script execute it.
      if (s.count>0) and (autoassemble(s,false)=false) then
      begin
        //on error write the script to the clipboard
        clipboard.AsText:=s.text; //debug
      end;
    finally
      s.free;
    end;


  end;


end;

function safed3dhook(size: integer=16*1024*1024; hookwindow: boolean=true): TD3DHook;
//Calls the d3dhook constructor but captures exceptions
var wr: DWORD;
begin
  if d3dhook=nil then
  begin
    try
      d3dhook:=TD3DHook.Create(size, hookwindow);
    except
      d3dhook:=nil;
    end;
  end
  else
  begin
    if d3dhook.processid<>processid then //different process
    begin
      d3dhook.Free;
      try
        d3dhook:=TD3DHook.Create(size, hookwindow);
      except
        d3dhook:=nil;
      end;
    end
    else
    begin
      //same process
      wr:=WaitForSingleObject(processhandle, 0);
      if wr<>WAIT_TIMEOUT then //not alive anymore
        freeandnil(d3dhook);

    end;

  end;

  result:=d3dhook;

end;

end.
