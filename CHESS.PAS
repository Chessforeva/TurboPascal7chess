
 {Chess program for DOS Turbo Pascal 7}

program Chess;

Uses Graph;  {Crt uz jaunakiem datoriem rada kludu Division by zero, tapec izmantoju assembleru}

{Pirms starte, izvelne iet uz File>Change dir un uzstada
 paskala BGI katalogu. Citadi nedarbosies.}

Var X0,Y0: Integer; {grafikas koordinatas kur zimet} 
     rw: Integer; {linija p.k.}
     pc: Char; {figura}
     bg: Integer; {tumss vai gaiss laucins}
     fC: Integer; {vai uz laucina ir 1:kursors, 2:gajiens no, 3:gajiens uz}

type VH = record
      v: Integer; {vertikale}
      h: Integer; {horizontale}
        end;

    {globalie mainigie, vajag algoritmam}
var Invert: Boolean; {ja spelejam ar melnajiem}
var Calc: Boolean; {ja iekseja kalkulacija, tad neko nezimet un pieraksta nesaglabat}

    {aktivie laucini, vadamiba ar peli un kursoru}
var CU: VH;
    MF: VH; {bus gajiens no, 1.click}
    MT: VH; {gajiens uz, 2.click}

    {assemblera kods, kas aizstaj ReadKey un peles funkcionalitati}
var M_x, M_y: Integer; {pele atrodas uz ekrana koordinatas}
    M_b: Integer; {peles kreisa &1,laba poga &2}

    procedure ReadAsmMouse; {nosaka peles stavokli, programmaa netiek izmantots}
    begin
        asm   {assembleris}
           mov ax,3
           mov M_x,cx {0..639}
           mov M_y,dx {0..199}
           int $33
           mov M_b,bx
        end;
    end;

    function KbHitAsm: Boolean; {nosaka vai taustins ir bijis nospiests}
    var ret: Char;
    begin
        asm   {assembleris}
           mov ah, 11
           int $21
           mov ret,al
        end;
        KbHitAsm:= (ret<>chr(0));
    end;

var Key: Char; {nospiestais taustins}

    procedure ReadAsmKey; {gaida nospiestu taustinu un ieliek to ieks Key}
    begin
        asm   {assembleris}
           mov ah, 7
           int $21
           mov Key,al
        end;
    end;

       {uzstada kursora poziciju uz ekrana}
    procedure SetAsmCPos( x_pos: Integer; y_pos: Integer );
    var xC,yC: Char;
    begin
        xC:=chr(x_pos); yC:=chr(y_pos);
        asm   {assembleris}
           mov ah, 2
           mov dh, yC {0..29}
           mov dl, xC {0..79}
           mov bx, 0
           int $10
        end;
    end;

    {saha sakumpozicija}
const SakPoz = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

type HS = record {elements gajienu vesturei}
    sqf: VH;     {no kura laucina}
    sqt: VH;     {uz kuru laucinu}
    cp: Char;    {figura, kura stav pirms gajiena uz laucina, uz kuru iet}
    ep: VH;      {garamsisana iespejama pirms gajiena}
    pr: Boolean; {bandinieks palika par figuru}
    cs: array [1..4] of Char;  {rokades iespejamas pirms gajiena}
        end;


var BO: array [1..8,1..8] of Char; {galdins}
    GW: Boolean; {gajiens baltiem vai melniem}
    CS: String;  {kuras rokades drikst taisit}
    EP: VH;      {ja iespejama garamsisana}
    WK: VH;      {baltas karalis kur atrodas}
    BK: VH;      {melnais karalis kur atrodas}
    NM: String;  {nakamie iespejamie gajieni}

var MHIST: array [1..160] of HS; {gajienu vesturei, atceras max.80 pilnus gajienus}
    MH_Len: Integer; {cik elementus skatit}

var MNr: Integer; {gajiens pec kartas}
    PGN: array[1..2048] of Char; {partijas pieraksts}

   {garai partijai vajag uzturet garaku masivu 2Kb garu,
    te ir paligfunkcijas ta uzturesanai}

   function PgnLen: Integer;  {cik gars ir pieraksts}
   var i: Integer;
   begin
     i:=0;
     while PGN[i+1]<>chr(0) do i:=i+1;
     PgnLen:=i;
   end;

   procedure PgnClear; {saraksta iztirisana}
   var i,iL: Integer;
   begin
     iL:= PgnLen;
     for i:=1 to iL do PGN[i]:=chr(0);
   end;

   procedure PgnAdd(s: String); {pieliek pie saraksta}
   var i,iL: Integer;
   begin
     iL:= PgnLen;
     for i:=1 to Length(s) do PGN[iL+i]:=s[i];
   end;

   procedure PgnDelMv; {iznem pedejo gajienu no saraksta}
   var i,iL: Integer;
   begin
     iL:= PgnLen; i:=iL;
     while i>0 do begin
       if PGN[i]=' ' then begin
         while i<=iL do begin
           PGN[i]:=chr(0);
           i:=i+1;
         end;
         break;
       end;
       i:=i-1;
     end;
     if i<1 then PgnClear;
   end;

   function PgnLastChar: Char; {nosaka pedejo simbolu (saha vai mata zimes)}
   var iL: Integer;
       c: Char;
   begin
     iL:= PgnLen;
     if iL=0 then c:=' ' else c:=PGN[iL];
     PgnLastChar:=c;
   end;
 
   procedure PgnPrint; {izdruka pierakstu visa garuma}
   var i,iL: Integer;
   begin
     iL:= PgnLen;
     for i:=1 to iL do write( PGN[i] );
     writeln;
   end;     


      {Zime pa punktam laucina vienu no 30 linijam}
      procedure DrwLine(s:String);
      var i,clr,x1,y1: Integer;
          c: Char;
      begin
        if (rw>0) and (rw<31) then
        begin
         for i:=2 to 31 do begin
          c:=s[i];
          if bg=0 then clr:=Brown else clr:=LightGray; {fons}
          if c='w' then clr:=White;
          if c='b' then clr:=Black;
          if (rw=1) or (rw=30) or (i=2) or (i=31) then {specialais ramis}
            case fC of
            1: clr:=Blue; {kursoram}
            2: clr:=Green;{iesim no}
            3: clr:=Red;  {ejam uz}
            end;
          SetColor(clr);
          x1:=2*(X0+i-1)+2;
          y1:=2*(Y0+rw-1);
          Rectangle(x1,y1,x1+1,y1+1); {zime 2 blakus punktus lai lielaks attels}
         end;
        end;
        rw:=rw+1;
      end;

      {Atkode figuru no isaka pieraksta}
      procedure Drw(sc:String);
      var j,k,u,code: Integer;
          c: Char;
          s:String;
      begin
         s:= '';
         for j:=1 to Length(sc) do begin
          c:= sc[j];
          if c='0' then begin
            for u:=1 to 32 do s:= s + ' '; {tuksa linija}
            DrwLine(s);
            s:= '';
          end;
          if (c='w') or (c='b') or (c=' ') then {punkts balts,melns vai fons}
          begin
            k := ord( sc[j-1] ) - ord('0'); {tik reizes atkartojas}
            for u:=1 to k do s:= s + c;
            if Length(s)=28 then begin
             DrwLine('  '+s+'  ');
             s:= '';
            end;
          end;
         end;
      end;

      {Zime vertikales,kolonas figuru no galdina}
      procedure DrawPiece(v:Integer; h:Integer);
      var hI,vI: Integer;
      begin
       rw:=0;
       if Invert then begin
         hI:=9-h;
         vI:=9-v;
       end else begin
         hI:=h;
         vI:=v;
       end;
       X0:=((hI-1)*30)+38;
       Y0:=((8-vI)*30)+1;

       bg:=(v+h) mod 2;
       pc:=BO[v,h];
       fC:=0;
       if(Mf.v=v) and (Mf.h=h) then fC:=2;
       if(Mt.v=v) and (Mt.h=h) then fC:=3;
       if(CU.v=v) and (CU.h=h) then fC:=1;
       Drw('0');

      {te seko iekodeti figuru atteli pec iespejas isak, jo bildes prasa daudz}
      case pc of
      'p': begin {Melns bandinieks}
       Drw('00008 3 5b8 4 8 3 6b8 3 8 2 7b8 3 ');
       Drw('8 2 7b8 3 8 2 7b8 3 8 2 7b8 3 8 3 4b1w2b8 2 ');
       Drw('8 1 8b2b8 1 8 1 8b2b8 1 8 1 8b2b8 1 ');
       Drw('8 1 8b2b8 1 8 2 8b8 2 8 1 8b1b8 2 ');
       Drw('8 8b1w2b8 1 7 8b2b1w2b8 7 8b6b7 ');
       Drw('6 8b7b7 6 8b7b7 5 8b8b1b6 5 8b8b1b6 ');
       Drw('5 8b8b1b6 5 8b8b1b6 00');
      end;
      'b': begin {Melns laidnis}
       Drw('08 5 2b8 5 8 4 4b8 4 8 4 4b8 4 ');
       Drw('8 4 4b8 4 8 4 4b8 4 8 3 6b8 3 8 1 8b2b8 1 ');
       Drw('8 8b3b8 1 8 5b2w5b8 7 5b4w4b8 7 6b2w6b7 ');
       Drw('7 8b6b7 7 8b6b7 7 8b5b8 8 8b4b8 ');
       Drw('8 1 1b8w1b8 1 8 1 8b2b8 1 8 8b4b8 ');
       Drw('8 8w4w8 8 8b4b8 8 1 8b2b8 1 8 2 8b8 2 ');
       Drw('3 8b8b6b3 2 8b8b8b2 2 8b3b2 8b3b2 00');
      end;
      'n': begin {Melns zirgs}
       Drw('0007 2b3 2b8 6 7 3b1 3b8 6 7 8b1b1w8 3 ');
       Drw('7 8b2b2w8 1 6 8b5b1w1b7 6 2b1w8b3b1w1b6 ');
       Drw('5 2b2w8b4b1w1b5 5 8b8b2b5 4 8b8b2b1w1b4 ');
       Drw('3 8b8b3b1w1b4 3 8b8b4b1w1b3 2 8b8b5b1w1b3 ');
       Drw('2 8b3b1 8b1b1w1b3 2 2b1w6b3 8b1b1w1b3 ');
       Drw('2 8b3 8b2b1w1b3 2 7b3 8b3b2w1b2 ');
       Drw('3 5b3 8b5b1w1b2 8 2 8b6b1w1b2 8 2 8b6b1w1b2 ');
       Drw('8 1 8b7b1w1b2 8 1 8b7b1w1b2 8 8b8b1w1b2 ');
       Drw('8 8b7b2w1b2 00');
      end;
      'r': begin {Melns tornis}
       Drw('00005 4b3 4b3 4b5 5 8b8b2b5 5 8b8b2b5 ');
       Drw('5 8b8b2b5 6 8b8b6 7 1b8w4w1b7 7 8b6b7 ');
       Drw('7 8b6b7 7 8b6b7 7 8b6b7 7 8b6b7 ');
       Drw('7 8b6b7 7 8b6b7 7 8b6b7 7 8b6b7 ');
       Drw('7 8b6b7 6 1b8w6w1b6 6 8b8b6 6 8b8b6 ');
       Drw('4 3b8w6w3b4 4 8b8b4b4 4 8b8b4b4 00');
      end;
      'q': begin {Melna dama}
       Drw('08 5 2b8 5 7 2b3 4b3 2b7 6 4b2 1b1w2b2 4b6 ');
       Drw('6 1b1w2b3 2b3 2b1w1b6 1 3b3 2b4 2b4 3b2 3b1 ');
       Drw('2b1w1b3 2b4 2b4 2b3 1b1w2b1 3b3 2b4 2b4 2b3 3b1 ');
       Drw('2 2b3 3b3 2b3 3b3 2b2 3 2b2 3b3 2b3 3b2 2b3 ');
       Drw('3 2b2 3b2 4b2 3b2 2b3 3 3b1 4b1 4b1 4b1 3b3 ');
       Drw('3 3b1 4b1 4b1 4b1 3b3 3 8b8b6b3 ');
       Drw('4 8b8b4b4 4 8b8b4b4 4 8b8b4b4 4 8b8b4b4 ');
       Drw('5 7b4w7b5 6 1w8b6b1w6 6 8b8b6 6 1b8w6w1b6 ');
       Drw('5 8b8b2b5 5 6w6b5w1b5 5 8b8b2b5 5 8b8b2b5 00');
      end;
      'k': begin {Melns karalis}
       Drw('008 5 2b8 5 8 4 4b8 4 8 5 2b8 5 ');
       Drw('8 5 2b8 5 8 4 4b8 4 8 4 4b8 4 8 3 6b8 3 ');
       Drw('4 6b1 6b1 6b4 3 1b6w8b6w1b3 2 1b1w6b2w4b2w6b1w1b2 ');
       Drw('2 1w8b2w2b2w8b1w2 2 1w8b1b4w8b1b1w2 ');
       Drw('2 1w8b2b2w8b2b1w2 2 2w8b1b2w8b1b1w1b2 ');
       Drw('2 1b2w8b2w8b2w3 3 1b2w3b8w5b2w1b3 ');
       Drw('4 1b5w7b6w1b4 5 8b8b2b5 6 4b8w4b6 ');
       Drw('6 1b3w7b4w1b6 6 6b3w7b6 6 1b8w5w2b6 ');
       Drw('6 8b8b6 7 8b5b8 8 2 7b8 3 0');
      end;
      'P': begin {Balts bandinieks}
       Drw('00008 3 5b8 4 8 3 1b3w2b8 3 8 2 1b5w1b8 3 ');
       Drw('8 2 1b5w1b8 3 8 2 2b3w2b8 3 8 2 1b5w2b8 2 ');
       Drw('8 1 1b7w1b8 2 8 1 1b7w2b8 1 8 1b8w1w1b8 1 ');
       Drw('8 1b8w1w1b8 1 8 1 1b7w2b8 1 8 1 2b6w1b8 2 ');
       Drw('8 2 1b5w2b8 2 8 2b7w2b8 1 7 2b8w2w1b8 ');
       Drw('7 1b8w3w2b7 6 1b8w5w1b7 6 1b8w5w2b6 ');
       Drw('5 1b8w7w1b6 5 1b8w7w1b6 5 1b8w7w1b6 5 8b8b1b6 00');
      end;
      'B': begin {Balts laidnis}
       Drw('08 5 2b8 5 8 4 4b8 4 8 4 1b2w1b8 4 ');
       Drw('8 4 1b2w1b8 4 8 4 4b8 4 8 3 2b2w2b8 3 ');
       Drw('8 1 2b6w2b8 1 8 2b8w1b8 1 8 1b4w2b4w1b8 ');
       Drw('7 2b3w4b3w1b8 7 1b5w2b5w1b7 7 1b8w4w1b7 ');
       Drw('7 1b8w4w1b7 7 2b8w2w1b8 8 2b8w2b8 ');
       Drw('8 1 8b2b8 1 8 1 1b8w1b8 1 8 2b8w2b8 ');
       Drw('8 8b4b8 8 1b8w2w1b8 8 1 4b2w4b8 1 ');
       Drw('8 2 8b8 2 3 8b6w8b3 2 2b8w4b8w2b2 2 8b3b2 8b3b2 00');
      end;
      'N': begin {Balts zirgs}
       Drw('0007 2b2 3b8 6 7 1b1w3b1w2b8 5 ');
       Drw('7 1b2w1b2w5b8 2 7 1b8w1w3b8 6 2b8w3w2b7 ');
       Drw('5 2b1w1b8w3w2b6 5 1b1w2b8w4w2b5 ');
       Drw('4 2b8w8w1b5 4 1b8w1w2b6w2b4 3 2b8w1w1b8w1b4 ');
       Drw('3 1b8w1w2b8w1b4 2 2b8w3b8w2b3 2 1b1w1b6w2b1 1b8w2b3 ');
       Drw('2 1b1w1b4w3b1 2b8w1w1b3 2 1b5w2b3 1b8w2w1b3 ');
       Drw('2 1b4w2b3 2b8w2w1b3 3 5b3 2b8w3w2b2 ');
       Drw('5 2b3 2b8w5w1b2 8 1 2b8w6w1b2 8 1 1b8w7w1b2 ');
       Drw('8 2b8w7w1b2 8 1b8w8w1b2 8 8b8b2b2 00');
      end;
      'R': begin {Balts tornis}
       Drw('00005 4b3 4b3 4b5 5 1b2w5b2w5b2w1b5 ');
       Drw('5 1b8w8w1b5 5 2b8w6w2b5 5 2b8w6w2b5 ');
       Drw('6 2b8w4w2b6 7 8b6b7 7 1b8w4w1b7 ');
       Drw('7 1b8w4w1b7 7 1b8w4w1b7 7 1b8w4w1b7 ');
       Drw('7 1b8w4w1b7 7 1b8w4w1b7 7 1b8w4w1b7 ');
       Drw('7 8b6b7 7 1b8w4w1b7 6 8b8b6 6 1b8w6w1b6 ');
       Drw('6 1b8w6w1b6 4 8b8b4b4 4 1b8w8w2w1b4 4 8b8b4b4 00');
      end;
      'Q': begin {Balta dama}
       Drw('08 5 2b8 5 7 2b3 4b3 2b7 6 1b2w1b2 1b2w1b2 4b6 ');
       Drw('6 1b2w1b2 4b2 1b2w1b6 1 3b2 3b4 2b3 4b2 3b1 ');
       Drw('1b2w1b3 2b4 2b4 2b3 1b2w1b1 3b3 2b4 2b4 2b3 3b1 ');
       Drw('2 2b3 3b3 2b3 3b3 2b2 3 2b2 3b2 4b2 3b2 2b3 ');
       Drw('3 2b2 4b1 1b2w1b1 4b2 2b3 3 3b1 2b1w1b1 1b2w1b1 1b1w2b1 3b3 ');
       Drw('3 1b1w4b1w3b2w3b1w4b1w1b3 3 1b2w3b2w2b2w2b2w3b2w1b3 ');
       Drw('3 2b2w2b2w2b2w2b2w2b2w2b3 4 1b2w8b7b1w1b4 ');
       Drw('4 4b8w4w4b4 4 1b8w8w2w1b4 5 1b6w4b6w1b5 ');
       Drw('5 3b8w4w3b5 6 1b8w6w1b6 6 8b8b6 ');
       Drw('5 2b8w6w2b5 5 6b6w6b5 4 2b8w8w1b5 5 8b8b2b5 00');
      end;
      'K': begin {Balts karalis}
       Drw('008 5 2b8 5 8 4 4b8 4 8 5 2b8 5 ');
       Drw('8 5 2b8 5 8 4 4b8 4 8 4 1b2w1b8 4 ');
       Drw('8 3 1b4w1b8 3 4 6b1 1b4w1b1 6b4 ');
       Drw('3 1b5w3b4w2b5w2b3 2 1b8w2b2w2b7w2b2 ');
       Drw('2 1b8w1w1b2w1b8w1w1b2 2 1b8w2w2b8w2w1b2 ');
       Drw('2 1b8w2w2b8w2w1b2 2 1b8w2w2b8w2w1b2 ');
       Drw('2 2b8w1w2b8w1w1b3 3 2b4w8b6w2b3 ');
       Drw('4 6b7w7b4 5 2b8w5w2b6 6 1b3w8b3w1b6 ');
       Drw('6 4b7w5b6 6 1b5w3b5w2b6 6 8b8b6 ');
       Drw('6 2b8w3w3b6 7 5b4w4b8 8 2 7b8 3 0');
      end;
      ' ': Drw('0000000000000000000000000000'); {tuks laucins}
      end;
      Drw('00');

      end;

      {Zime visu galdinu}
      procedure DrawPosition;
      var v,h: Integer;
      begin
         for v:=1 to 8 do begin
          for h:=1 to 8 do begin
           DrawPiece(v,h);
          end;
         end;
      end;

      {Uzstada poziciju no FEN standarta pieraksta}
      procedure SetFENposition(s:String);
      var i,v,h,k,u,code: Integer;
          c:Char;
       epSq,gaj: String;
      begin
         for v:=1 to 8 do for h:=1 to 8 do BO[v][h]:=' ';
         CS:='';
         epSq:=''; gaj:='';
         v:=8;
         h:=1;
         u:=0;
         for i:=1 to Length(s) do begin
          c:= s[i];
          if c=' ' then u:=u+1
          else begin
            k:= ord(c)-ord('0');
            case u of
            0: begin  {figuru izvietojums}
             if (k>0) and (k<9) then h:=h+k
             else begin
              if c<>'/' then begin
               BO[v,h]:=c;
               case c of
               'K': begin WK.v:=v; WK.h:=h; end;
               'k': begin BK.v:=v; BK.h:=h; end;
               end;
               h:=h+1;
              end;
             end;
             if h>8 then begin
              v:=v-1;
              h:=1;
             end;
            end;
            1: GW:=(c='w'); {kam gajiens}
            2: CS:=CS+c;    {rokades}
            3: epSq:=epSq+c;    {garamsisana tagad}
            4: ;{pusgajieni kops pedejas figuras sisanas, ignorejam}
            5: gaj:=gaj+c;  {gajiena numurs}
            end;
          end;
         end;

         if Length(epSq)=2 then
           with EP do begin
            v:= ord(epSq[2])-ord('0');
            h:= 1+ord(epSq[1])-ord('a');
           end
         else begin
           EP.v:=0; EP.h:=0;
         end;

         MH_Len:=0; {iztira gajienu vesturi}
         PgnClear;   {tukss pieraksts}
         Val(gaj,MNr,code); {gajiena numurs tagad ieks MNr}

         MF.v:=0; MF.h:=0;
         MT.v:=0; MT.h:=0;
         CU.v:=2; CU.h:=5; {kursors atrodas uz e2 vai e7}
         if Invert then CU.v:=7 else CU.v:=2;

      end;
    
           {paligfunkcijas}
      function isEmpty (v: Integer; h: Integer):Boolean;
      begin
       isEmpty:= ( BO[v][h]=' ' );
      end;
      function isWhite (v: Integer; h: Integer):Boolean;
      begin
       isWhite:= ( (BO[v][h]<>' ') and (ord(BO[v][h])<ord('a')) );
      end;
      function isBlack (v: Integer; h: Integer):Boolean;
      begin
       isBlack:= ( (BO[v][h]<>' ') and (ord(BO[v][h])>ord('a')) );
      end;


      {parbauda vai laucinjam nav uzbrukts visos virzienos}
     function isKingAttack( v: Integer; h: Integer): Boolean;
     var dv,dh,vt,ht,ds: Integer;
         c: Char;
         is: Boolean;

       function isKnight ( v0: Integer; h0: Integer; dv: Integer; dh: Integer ): Boolean;
       var vN,hN: Integer;
           cN: Char;
       begin
        if(GW) then cN:='n' else cN:='N';
        vN:= v0+dv; hN:= h0+dh;
        if (vN>0) and (vN<9) and (hN>0) and (hN<9) then isKnight:=(BO[vN,hN]=cN) else isKnight:=False;
       end;

     begin
        is:= False;
        for dv:=-1 to 1 do begin
         for dh:=-1 to 1 do begin
           if (dv<>0) or (dh<>0) then begin
             vt:=v+dv; ht:=h+dh; ds:=1;
             while (not is) and (vt>0) and (vt<9) and (ht>0) and (ht<9) do begin
               c:= BO[vt,ht];
               if not isEmpty(vt,ht) then begin
                 if (GW=isBlack(vt,ht)) then begin
                   if ds=1 then begin
                    case c of
                    'K','k': is:=True;
                    'p': if (dv>0) and (dh<>0) then is:=True;
                    'P': if (dv<0) and (dh<>0) then is:=True;
                    end;
                   end;
                   case c of
                   'B','b': if(dv<>0) and (dh<>0) then is:=True;
                   'R','r': if(dv=0) or (dh=0) then is:=True;
                   'Q','q': is:=True;
                   end;
                 end;
                 break;
               end;
               vt:=vt+dv; ht:=ht+dh; ds:=ds+1;
             end;
           end;
         end;
        end;
            {zirgi atseviski}
        if (not is) and
	   (isKnight( v,h,-2,-1 ) or isKnight( v,h,-2,1 ) or
            isKnight( v,h,-1,-2 ) or isKnight( v,h,-1,2 ) or
            isKnight( v,h,2,-1 ) or isKnight( v,h,2,1 ) or
            isKnight( v,h,1,-2 ) or isKnight( v,h,1,2 )) then is:=True;
         
        isKingAttack:=is;
     end;


       {ja karalis shobrid atrodas zem saha}
     function isCheck: Boolean;
     var KG: VH;
     begin
       if GW then KG:=WK else KG:=BK;
       isCheck:= isKingAttack( KG.v, KG.h );
     end;

           {Genere nakamos gajienus mainigaja NM}
      procedure GenNextMoves;
      var v,h, v2, h2: Integer;
          c:Char;

        {pievieno gajienu sarakstam}
       procedure Add2List (vf: Integer; hf: Integer; vt: Integer; ht: Integer);
       begin
         NM:= NM + chr( ord('a')+hf-1 )+chr( ord('0')+vf )+ chr( ord('a')+ht-1 )+chr( ord('0')+vt )+';';
       end;

        {parbauda vai karalis nav palicis zem uzbrukuma pec gajiena veiksanas}
       procedure AddMove (vf: Integer; hf: Integer; vt: Integer; ht: Integer);
       var Bt: Char;
           KG: VH;
       begin
         Bt:=BO[vt,ht]; BO[vt,ht]:=BO[vf,hf]; BO[vf,hf]:=' ';  {imite izmainas uz galdina}
         if GW then KG:=WK else KG:=BK;
         if (vf=KG.v) and (hf=KG.h) then begin   {ja karalis pats paiet}
           KG.v:=vt; KG.h:=ht;
         end;
         if not isKingAttack( KG.v, KG.h ) then Add2List(vf,hf,vt,ht);  {ja nav apdraudets,tad der}
         BO[vf,hf]:=BO[vt,ht]; BO[vt,ht]:=Bt;
       end;

           {pievieno rokades gajienus}
       procedure AddRokade (KG: VH; dh: Integer);
       var ht: Integer;
           can: Boolean;
       begin
         if not isKingAttack( KG.v, KG.h ) then begin   {ja nav sahs}
           ht:=KG.h+dh;
           can:=True;
           while can and (ht>1) and (ht<8) do begin
            if not isEmpty(KG.v,ht) then can:=False;
            if can and (ht>2) and (ht<8) and isKingAttack( KG.v, ht ) then can:=False;
            ht:=ht+dh;
           end;
           if can then Add2List( KG.v, KG.h, KG.v, KG.h+(2*dh) );
         end;
       end;

           {pieliek vien-gajienus}
       procedure Add1m (vf: Integer; hf: Integer; vt: Integer; ht: Integer);
       begin
         if (vt>0) and (vt<9) and (ht>0) and (ht<9) then
           if isEmpty(vt,ht) or (GW=isBlack(vt,ht)) then AddMove(vf,hf,vt,ht);
       end;
           {pieliek diognalos, horizontalos un vertikalos figuru gajienus}
       procedure AddDr (vf: Integer; hf: Integer; dv: Integer; dh: Integer);
       var vt,ht: Integer;
       begin
         vt:=vf+dv; ht:=hf+dh;
         while (vt>0) and (vt<9) and (ht>0) and (ht<9) do begin
           if isEmpty(vt,ht) then AddMove(vf,hf,vt,ht)
           else begin
             if (GW=isBlack(vt,ht)) then AddMove(vf,hf,vt,ht);
             break;
           end;
           vt:=vt+dv; ht:=ht+dh;
         end;
       end;

      begin

        NM:='';
        for v:=1 to 8 do begin
         for h:=1 to 8 do begin
          c:= BO[v][h];
          if ( ord(c)<ord('a') )=GW then begin   {skatas tikai figuras tam kam gajiens}
            case c of
            ' ': {empty square};
            'p': begin
              if isEmpty(v-1,h) then begin
                AddMove(v,h,v-1,h);
                if (v=7) and isEmpty(v-2,h) then AddMove(v,h,v-2,h);
              end;
              if (h>1) and (isWhite(v-1,h-1) or ((v-1=EP.v) and (h-1=EP.h))) then AddMove(v,h,v-1,h-1);
              if (h<8) and (isWhite(v-1,h+1) or ((v-1=EP.v) and (h+1=EP.h))) then AddMove(v,h,v-1,h+1);
            end;
            'P': begin
              if isEmpty(v+1,h) then begin
                AddMove(v,h,v+1,h);
                if (v=2) and isEmpty(v+2,h) then AddMove(v,h,v+2,h);
              end;
              if (h>1) and (isBlack(v+1,h-1) or ((v+1=EP.v) and (h-1=EP.h))) then AddMove(v,h,v+1,h-1);
              if (h<8) and (isBlack(v+1,h+1) or ((v+1=EP.v) and (h+1=EP.h))) then AddMove(v,h,v+1,h+1);
            end;
            'n','N': begin
              Add1m( v,h,v-2,h-1 ); Add1m( v,h,v-2,h+1 );
              Add1m( v,h,v-1,h-2 ); Add1m( v,h,v-1,h+2 );
              Add1m( v,h,v+2,h-1 ); Add1m( v,h,v+2,h+1 );
              Add1m( v,h,v+1,h-2 ); Add1m( v,h,v+1,h+2 );
            end;
            'b','B', 'r','R', 'q','Q': begin
              if (c<>'r') and (c<>'R') then begin
               AddDr( v,h,1,1 ); AddDr( v,h,-1,1 );
               AddDr( v,h,1,-1 ); AddDr( v,h,-1,-1 );   
              end;
              if (c<>'b') and (c<>'B') then begin
               AddDr( v,h,1,0 ); AddDr( v,h,-1,0 );
               AddDr( v,h,0,-1 ); AddDr( v,h,0,1 );
              end;
            end;
            'k','K': begin
              Add1m( v,h,v-1,h-1 ); Add1m( v,h,v-1,h ); Add1m( v,h,v-1,h+1 );
              Add1m( v,h,v,h+1 ); Add1m( v,h,v,h-1 );
              Add1m( v,h,v+1,h-1 ); Add1m( v,h,v+1,h ); Add1m( v,h,v+1,h+1 );
              case c of              
              'K': begin  {baltas rokades}
               if Pos('K',CS)>0 then AddRokade(WK,1);
               if Pos('Q',CS)>0 then AddRokade(WK,-1);
              end;
              'k': begin  {melnas rokades}
               if Pos('k',CS)>0 then AddRokade(BK,1);
               if Pos('q',CS)>0 then AddRokade(Bk,-1);
              end;
              end;
            end;
            end;
 
            
          end
          
         end;
        end;
      end;


         {Izdara gajienu mainigajos, saglaba atminas masivaa.
          Ertibas labad parametri ir uci pieraksts pa simbolam, t.i. 5 zimes}
     procedure MakeMove(Chf: Char; Cvf: Char; Cht: Char; Cvt: Char; prom: Char);
     var pi,capt: Char;
         vf,hf,vt,ht: Integer;
         HE: HS;
         i: Integer;
         num:String;
         pg:String;

      procedure CSrmv(Cc: Char); {iznem rokades iespeju}
      var j: Integer;
      begin
        j:=Pos(Cc,CS);
        if j>0 then Delete(CS,j,1);
      end;
     begin
         vf:= ord(Cvf)-ord('0');
         hf:= 1+ord(Chf)-ord('a');
         vt:= ord(Cvt)-ord('0');
         ht:= 1+ord(Cht)-ord('a');

         HE.sqf.v:=vf;
         HE.sqf.h:=hf;
         HE.sqt.v:=vt;
         HE.sqt.h:=ht;
         HE.cp:=BO[vt][ht]; {te bija figura}
         HE.ep:=EP;    {garamsisana pirms}
         HE.pr:=False;
         for i:=1 to 4 do  {rokades iespejamas bija}
          if Length(CS)<i then HE.cs[i]:=' ' else HE.cs[i]:=CS[i];

         if (HE.cp<>' ') or ((EP.v=vt) and (EP.h=ht)) then capt:='x' else capt:='-';
         pg:='';
           
         pi:=BO[vf][hf];

         if (not Calc) and (PgnLen>0) then PgnAdd(' '); {ja bijusi gajieni, ieliekam atstarpi}

         if (not Calc) and GW then begin   {baltiem gajiena numurs pieraksta}
           Str(MNr,num);
           PgnAdd( num + '.' );
         end;

         if(pi='p') or (pi='P') then begin
           if(vt=1) or (vt=8) then begin
             HE.pr:=True;
             if prom=' ' then prom:='q';
             if(GW) then prom:=UpCase(prom);
             pi:=prom;  {uzliekam damu vai citu figuru}
           end;
           if (EP.v=vt) and (EP.h=ht) then begin
             BO[vf][ht]:=' ';  {garamsisana, nonem bandinieku}
             if(not Calc) then DrawPiece(vf,ht);
           end;
         end else
           pg:= pg + UpCase(pi);
         
         pg:= pg + chr( ord('a')+hf-1 )+chr( ord('0')+vf ) + capt +
                      chr( ord('a')+ht-1 )+chr( ord('0')+vt );
                  
         BO[vt][ht]:=pi;   {pabidam parliekot figuru}
         BO[vf][hf]:=' ';  {figura te vairs nav}

         if(not Calc) then begin
           DrawPiece(vf,hf);  {zime uz ekrana}
           DrawPiece(vt,ht);
         end;

         if(GW) then begin
           case pi of
           'K': begin {ja baltais karalis pakustas}
             WK:=HE.sqt;
             CSrmv('K'); CSrmv('Q');
             if hf=5 then
              case ht of {ja balta karala rokade}
              7: begin
                BO[1,6]:=BO[1,8]; BO[1,8]:=' '; pg:='0-0'; {tornis uz f1}
                if(not Calc) then begin
                  DrawPiece(1,6); DrawPiece(1,8);
                end;
                 end;
              3: begin
                BO[1,4]:=BO[1,1]; BO[1,1]:=' '; pg:='0-0-0'; {tornis uz c1}
                if(not Calc) then begin
                  DrawPiece(1,4); DrawPiece(1,1);
                end;
                 end;
              end;
            end;
            'R': begin
              if (hf=1) and (vf=1) then CSrmv('Q'); {ja tornis pagajis, rokade izjaukta}
              if (hf=8) and (vf=1) then CSrmv('K');
            end;
           end;
           if (ht=1) and (vt=1) then CSrmv('Q'); {ja tornis nosists, rokade izjaukta}
           if (ht=8) and (vt=1) then CSrmv('K');
         end else begin
           case pi of
           'k': begin {ja melnais karalis pakustas}
             BK:=HE.sqt;
             CSrmv('k'); CSrmv('q');
             if hf=5 then
              case ht of {ja melna karala rokade}
              7: begin
                BO[8,6]:=BO[8,8]; BO[8,8]:=' '; pg:='0-0'; {tornis uz f8}
                if(not Calc) then begin
                  DrawPiece(8,6); DrawPiece(8,8);
                end;
                 end;
              3: begin
                BO[8,4]:=BO[8,1]; BO[8,1]:=' '; pg:='0-0-0'; {tornis uz c8}
                if(not Calc) then begin
                  DrawPiece(8,4); DrawPiece(8,1);
                end;
                 end;
              end;
            end;
            'r': begin
              if (hf=1) and (vf=8) then CSrmv('q'); {ja tornis pagajis, rokade izjaukta}
              if (hf=8) and (vf=8) then CSrmv('k');
            end;
           end;
           if (ht=1) and (vt=8) then CSrmv('q'); {ja tornis nosists, rokade izjaukta}
           if (ht=8) and (vt=8) then CSrmv('k');
         end;

         EP.v:=0; EP.h:=0;    {iegaumejam nakamo garamsisanas iespeju}
         if (pi='P') and (vf=2) and (vt=4) then EP.v:=3;
         if (pi='p') and (vf=7) and (vt=5) then EP.v:=6;
         if EP.v>0 then EP.h:=ht;

         if (not Calc) then PgnAdd(pg);
 
         if (not GW) then MNr:= MNr+1; {pec melno gajiena seko nakamais gajiens}

         MH_Len:= MH_Len + 1;
         MHIST[ MH_Len ]:=HE;
         GW:=(not GW);
  
     end;


        {izmanto gajienu vesturi un atliek atpakal pedejo gajienu}
     procedure UnMakeMove;
     var i,vf,hf,vt,ht: Integer;
         c,pi: Char;
         HE: HS;
     begin
       if MH_Len>0 then begin
         HE:= MHIST[ MH_Len ];
         MH_Len:= MH_Len - 1;

         vf:=HE.sqf.v; hf:=HE.sqf.h;
         vt:=HE.sqt.v; ht:=HE.sqt.h;

         pi:=BO[vt][ht];

         if HE.pr then {ja bandinieks bija iegajis dama}
           case vt of
           1: pi:='p';
           8: pi:='P';
           end;

         BO[vf][hf]:=pi;    {no sejienes figura pagaja}
         BO[vt][ht]:=HE.cp; {atliek nosisto figuru vai tuksumu}

         if(not Calc) then begin
           DrawPiece(vf,hf);  {zime uz ekrana}
           DrawPiece(vt,ht);
         end;

         if (HE.cp=' ') and (hf<>ht) then begin
           case pi of
           'p': c:='P';
           'P': c:='p';
           else c:=' ';
           end;
           if c<>' ' then begin
              BO[vf][ht]:=c;  {atliek pretejo bandinieku pirms garamsisanas}
              if(not Calc) then DrawPiece(vf,ht);
           end;
           if hf=5 then
            case pi of
            'k': begin  {atliekam torni melna karala rokadei}
               case ht of
               7: begin
                  BO[8,8]:=BO[8,6]; BO[8,6]:=' ';
                  if(not Calc) then begin
                    DrawPiece(8,6); DrawPiece(8,8);
                  end;
                  end;
               3: begin
                  BO[8,1]:=BO[8,4]; BO[8,4]:=' ';
                  if(not Calc) then begin
                    DrawPiece(8,4); DrawPiece(8,1);
                  end;
                  end;
               end;
              end;
            'K': begin  {atliekam torni balta karala rokadei}
               case ht of
               7: begin
                  BO[1,8]:=BO[1,6]; BO[1,6]:=' ';
                  if(not Calc) then begin
                    DrawPiece(1,6); DrawPiece(1,8);
                  end
                  end;
               3: begin
                  BO[1,1]:=BO[1,4]; BO[1,4]:=' ';
                  if(not Calc) then begin
                    DrawPiece(1,4); DrawPiece(1,1);
                  end
                  end;
               end;
              end;
            end;
         end;

         case pi of    {karali atrodas te}
         'k': BK:= HE.sqf;
         'K': WK:= HE.sqf;
         end;

         CS:='';  {atliekam iespejamas rokades}
         for i:=1 to 4 do begin
           c:= HE.cs[i];
           if c<>' ' then CS:=CS+c;
         end;
         EP:=HE.ep;

         if (not Calc) then PgnDelMv; {partijas pieraksta nav pedeja gajiena}

         if (GW) then MNr:= MNr-1; {ieprieksejais gajiens pirms balto}
         GW:=(not GW);
       end;
     end;


      {Veic secigi gajienus saskana ar uci pierakstu, piemeram:e2e4 e7e5     a7a8q }
     procedure UCImoves(S:String);
     var i: Integer;
         prom: Char;
     begin
       i:=1;
       while i<=Length(S) do begin
         i:=i+4;
         prom:=' ';
         if i<=Length(S) then prom:=S[i];
         MakeMove(S[i-4],S[i-3],S[i-2],S[i-1],prom);
         if isCheck then begin  {ja sahs...}
           GenNextMoves;         {... vai var veikt kadu gajienu?}
           if Length(NM)=0 then PgnAdd('#')  {Mats uz galdina}
           else PgnAdd('+'); {tikai pieteikts sahs karalim}
         end;
         if prom<>' ' then i:=i+1;
         i:=i+1;
       end;
     end;


      {primitiva pozicijas novertesana, atgriez skaitli
       pozitivaks nozime baltiem labak, negativaks - melniem parsvars}
    function EvaluatePos: Integer;
    var v,h,ev,cv,ch,cn,cK: Integer;
        c: Char;
    begin
        ev:=0;
        for v:=1 to 8 do begin
         for h:=1 to 8 do begin
          c:= BO[v][h];
          ch:=abs(9-h-h); cv:=abs(9-v-v);
          cn:=ch+cv;  {attalums lidz centram, figuram jaiet uz to}
          cK:=abs(BK.v-WK.v)+abs(BK.h-WK.h);
          case c of
          'P': begin ev:=ev+300-(9-v); end; {vairak uz prieksu}
          'N': begin ev:=ev+900-cn; end;
          'B': begin ev:=ev+1000-cn; end;
          'R': begin ev:=ev+1500-cn;
               if v=7 then ev:=ev+15; {septita linija}
               end;
          'Q': begin ev:=ev+3000-cn; end;
          'K': begin ev:=ev+7000;
               if MNr<30 then ev:=ev+(ch+ch+cv) {karalim jamuk prom no centra, rokade un sturis}
               else ev:=ev-cK {karalim jaiet klat pie otra karala}
               end;
          'p': begin ev:=ev-300+v; end;
          'n': begin ev:=ev-900+cn; end;
          'b': begin ev:=ev-1000+cn; end;
          'r': begin ev:=ev-1500+cn;
               if v=2 then ev:=ev-15; {otra linija}
               end;
          'q': begin ev:=ev-3000+cn; end;
          'k': begin ev:=ev-7000;
               if MNr<30 then ev:=ev-(ch+ch+cv) {karalim jamuk prom no centra, rokade un sturis}
               else ev:=ev+cK {karalim jaiet klat pie otra karala}
               end;
          ' ': begin
            if (MNr<5) then begin
              if (v=2) then ev:=ev+(8-ch); { forse bandiniekus kustet uz prieksu }
              if (v=7) then ev:=ev-(8-ch);
            end;
               end;
          end;
         end;
        end;
        EvaluatePos:=ev+(random(6)-3);
    end;

      {Apskata nakamos gajienus. Labaka pozicija nozime labako gajienu.
       Izpilda visus atbildes gajienus un noverte poziciju pec.
       Ja pozicija tik un ta labaka, tad izvelas. }

    function Calculs:String;
    var ev0,i,ev,iB,evB, iA,evA, iAm,evAm : Integer;
       mv,NM2,NM3: String;
    begin

      Calc:=True;
      ev0:=EvaluatePos;
      i:=1;
      iB:=1;  {kurai saraksta ir labakais gajiens}
      evB:=0; {stiprakais novertejums}
      while i<Length(NM) do begin

        MakeMove(NM[i],NM[i+1],NM[i+2],NM[i+3],' ');
        ev:=EvaluatePos;

        NM2:=NM;
        GenNextMoves;  {rekinam atbildes gajienus}
        iA:=1;
        while iA<Length(NM) do begin
          MakeMove(NM[iA],NM[iA+1],NM[iA+2],NM[iA+3],' ');
          evA:=EvaluatePos;

          if isCheck then begin  {ja sahs...}
             NM3:=NM;
             GenNextMoves;  {parbaudam vai nav jaizvairas no mata}

             iAm:=1;     {apskatam musu gajienu pec tam, ja sitam figuru }
             while iAm<Length(NM) do begin
               MakeMove(NM[iAm],NM[iAm+1],NM[iAm+2],NM[iAm+3],' ');
               evAm:=EvaluatePos;
               if (GW and (evA>evAm)) or ((not GW) and (evA<evAm)) then evA:=evAm; {musu 2labakais}
               UnMakeMove;
               iAm:=iAm+5;
             end;

             if Length(NM)=0 then begin
               if(GW) then evA:=-9999 else evA:=9999;  {dabusim matu}
             end;
             NM:=NM3;
          end;

          if (GW and (ev>evA)) or ((not GW) and (ev<evA)) then ev:=evA;	{atbilde stipraka}
          UnMakeMove;
          iA:=iA+5;
        end;

        if isCheck then begin  {ja sahs...}
          if Length(NM)=0 then begin
            if(GW) then ev:=-9999 else ev:=9999;  {Mats uz galdina}
          end else begin
            if(GW) then ev:=ev-40 else ev:=ev+40; {tikai pieteikts sahs karalim}
          end;
        end;
        NM:=NM2;

        UnMakeMove; {atliekam atpakal poziciju}
        if (evB=0) or (GW and (ev>evB)) or ((not GW) and (ev<evB)) then begin 
          evB:=ev;
          iB:=i;
        end;
        i:=i+5;
      end;
      mv:=NM[iB]+NM[iB+1]+NM[iB+2]+NM[iB+3];
      Calc:=False;
      Calculs:=mv;
    end;

       {programma kalkule gajienu}
    procedure CalcMove;
    var u: String;
    begin
       GenNextMoves;
       if Length(NM)>0 then begin
         u:=Calculs;
         MF.v:=0; MF.h:=0;
         MT.v:=ord(u[4])-ord('0'); MT.h:=ord(u[3])-ord('a')+1;
         UCImoves(u);
       end;
    end;

     {galvenais cikls, kura lietotajs vada kursoru}
    procedure GalvCikls;
    var Kcode,k75,k77,k72,k80: Integer;
        Fsq,sq: String;
        M4: VH;

       {pievers uzmanibu laba augseja sturi, ka ir sahs vai mats}
     procedure ShowCheckOrMate;
     var disp: String;
         c: Char;
     begin
       disp:='         ';
       c:=PgnLastChar;
       case c of
        '+': disp:='Check+   ';
        '#': disp:='Checkmate';
       end;
       SetAsmCPos(71,2); Write(disp);
     end;

     procedure ShowCalc;  {Parada, ka doma}
     begin
       SetAsmCPos(71,2); Write('Thinking ');
     end;


    begin

      Calc:=False;      {zimet visu uz ekrana}
      CU.v:=2; CU.h:=5; {kursors atrodas uz e2}
      MF.v:=0; MF.h:=0;
      MT.v:=0; MT.h:=0;

      Kcode:=0;
      while Kcode<>27 do begin  {rinko kamer nav ESC}

       if KbHitAsm then begin

        ReadAsmKey;   {vada kursoru ar bultinam}
        Kcode:=ord(Key);
        if Kcode=0 then begin
          ReadAsmKey; {nolasa extended kodu}
          Kcode:=ord(Key);
        end;

        if Invert then begin {jasamaina vietam taustini}
          k75:=77;
          k77:=75;
          k72:=80;
          k80:=72;
        end else begin  {taustinu kodi bultinam}
          k75:=75;
          k77:=77;
          k72:=72;
          k80:=80;
        end;

        if(Kcode=k75) and (CU.h>1) then begin 
          CU.h:=CU.h-1; {pa kreisi}
          DrawPiece(CU.v,CU.h+1); DrawPiece(CU.v,CU.h);
        end;
        if(Kcode=k77) and (CU.h<8) then begin
          CU.h:=CU.h+1; {pa labi}
          DrawPiece(CU.v,CU.h-1); DrawPiece(CU.v,CU.h);
        end;
        if(Kcode=k72) and (CU.v<8) then begin 
          CU.v:=CU.v+1; {uz augsu}
          DrawPiece(CU.v-1,CU.h); DrawPiece(CU.v,CU.h);
        end;
        if(Kcode=k80) and (CU.v>1) then begin
          CU.v:=CU.v-1; {uz leju}
          DrawPiece(CU.v+1,CU.h); DrawPiece(CU.v,CU.h);
        end;
        case Kcode of
        32,13: begin     {izvelets laucins, Enter vai garais tuksnis}
               GenNextMoves;
               sq:=chr( ord('a')+CU.h-1 )+chr( ord('0')+CU.v );
               if (MF.v=0) or (Pos( sq+';', NM )<1) then begin
                 if Pos( ';'+sq, ';'+NM )>0 then begin
                   if MF.v>0 then begin
                     M4:= MF; MF.v:=0; MF.h:=0;
                     DrawPiece(M4.v,M4.h);     
                   end;
                   MF:=CU;
                   M4:=MT;
                   MT.v:=0; MT.h:=0;
                   if M4.v>0 then DrawPiece(M4.v,M4.h);
                 end;
               end;
               if (MF.v>0) then begin
                 Fsq:=chr( ord('a')+MF.h-1 )+chr( ord('0')+MF.v );
                 if Pos( Fsq + sq + ';', NM )>0 then begin
                   MF.v:=0; MF.h:=0;
                   if MH_Len>0 then begin
                     M4:= MHIST[ MH_Len ].sqt; MT.v:=0; MT.h:=0;
                     DrawPiece(M4.v,M4.h);
                   end;
                   MT:=CU;
                   UCImoves( Fsq + sq );
                   if Invert=GW then begin
                     ShowCalc;
                     CalcMove;
                   end;
                   ShowCheckOrMate;
                 end; 
               end;
            end;
        117,85: begin     { UNDO }
             MF.v:=0; MF.h:=0;
             if MT.v>0 then begin
               M4:= MT; MT.v:=0; MT.h:=0;
               DrawPiece(M4.v,M4.h);     
             end;
             UnMakeMove;
             if MH_Len>0 then begin
               MT:= MHIST[ MH_Len ].sqt;
               DrawPiece(MT.v,MT.h);
             end;
             ShowCheckOrMate;
             end;
        110,78: begin   { NEW GAME }
             Invert:=(not Invert);
             SetFENposition(SakPoz);
             DrawPosition;
             if Invert=GW then begin
               ShowCalc;
               CalcMove;
             end;
             ShowCheckOrMate;
             end;
        end;

       end;

      end;
    end;


    { Te sakas galvenais }
Var Gd, Gm : Integer; {grafikai}

Begin

     Randomize;
     Gd:=Detect;
     InitGraph(Gd, Gm, '');
     If GraphResult = grOk Then
     Begin

        { Te var sakt rakstit programmu, jo grafika darbojas }

         {dazhi uzraksti, lai lietotajs zinatu taustinus}
         SetAsmCPos(2,2); Writeln('Turbo');
         SetAsmCPos(2,3); Writeln('Pascal');
         SetAsmCPos(2,4); Writeln('Chess');

         SetAsmCPos(71,26); Write('U-Undo');
         SetAsmCPos(71,27); Write('N-New');
         SetAsmCPos(71,28); Write('Esc-Exit');

         Invert:= False;
         SetFENposition(SakPoz);

         DrawPosition; {uzzime poziciju}

         GalvCikls;  {te darbojas un zime izmainas}

        { Aizver grafikas rezimus }

        CloseGraph;

        PgnPrint; {izdruka partiju}

     End
     Else WriteLn('Izmeta grafikas kludu:', GraphErrorMsg(GraphResult));
End.
