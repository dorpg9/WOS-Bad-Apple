-- Bad Apple!
local pImages = {['normal']="rbxassetid://14750789446"}

--insertMarker_fileStringGet

local byte = string.byte --returns nil if no char at index
local char = string.char
local sub = string.sub
local sPack = string.pack
local sUnpack = string.unpack
local sPacksize = string.packsize
local rep = string.rep
local insert = table.insert
local remove = table.remove
local create = table.create
local clone = table.clone
local tPack = string.pack
local tUnpack = string.unpack
local roundFor8b = function(a)return a%256 end
local abs = math.abs
local ceil = math.ceil
local min = math.min
local fdiv = function(a,b)return math.floor(a/b)end
local avg = function(a,b)return math.floor((a+b)/2)end
local solidify = function(a)return function()return a end end

fileStringGet = fileStringGet or nil

-- Waste of Space Integration
local GetRequest, PostRequest, doTheThing, GetRun

local screens, subScreen, buildScreens = {},{},{}
local updateProgress, progressFrame, rendererFrame, decor
local metadata = {["width"]=480,["height"]=360,["frameCount"]=6573,["fps"]=30}
local aRatio, widthInChunks, heightInChunks, widthInRChunks, heightInRChunks = 4/3,120,90,60,90
local mSSize, rFSize, rCSize, cSize, cSizeS = {},{},{},{},{}



-- Large to Humongous Classes and Libraries, includes 3rd Party Software
local WOSscreenEmulator,LibDeflate,SignalConnection,Signal,bit32
do
	-- davidm/lua-bit-numberlua, GitHub
	do local a=2^32;local b=a-1;bit32={}local function d(e)local f={}local g=setmetatable({},f)function f:__index(h)local i=e(h)g[h]=i;return i end;return g end;local function j(g,k)local function l(m,n)local o,p=0,1;while m~=0 and n~=0 do local q,r=m%k,n%k;o=o+g[q][r]*p;m=(m-q)/k;n=(n-r)/k;p=p*k end;o=o+(m+n)*p;return o end;return l end;
		local function s(g)local t=j(g,2^1)local u=d(function(m)return d(function(n)return t(m,n)end)end)return j(u,2^(g.n or 1))end;local v=s{[0]={[0]=0,[1]=1},[1]={[0]=1,[1]=0},n=4}local function w(m,n)return(m+n-v(m,n))/2 end;local x,y;function y(m,z)if z<0 then return x(m,-z)end;return math.floor(m%2^32/2^z)end;local function bnot(m)return b-m end;
		function x(m,z)if z<0 then return y(m,-z)end;return m*2^z%2^32 end;local function A(B,z)z=z%32;local C=w(B,2^z-1)return y(B,z)+x(C,32-z)end;local function D(B,z)return A(B,-z)end;local function E(F,G,H)H=H or 1;return w(y(F,G),2^H-1)end;local function I(F,i,G,H)H=H or 1;local J=2^H-1;i=w(i,J)local K=bnot(x(J,G))return w(F,K)+x(i,G)end;
		local function L(B)return(-1-B)%a end;bit32.bnot=L;local function M(m,n,N,...)local O;if n then m=m%a;n=n%a;O=v(m,n)if N then O=M(O,N,...)end;return O elseif m then return m%a else return 0 end end;bit32.bxor=M;local function P(m,n,N,...)local O;if n then m=m%a;n=n%a;O=(m+n-v(m,n))/2;if N then O=P(O,N,...)end;return O elseif m then return m%a else return b end end;
		bit32.band=P;local function Q(m,n,N,...)local O;if n then m=m%a;n=n%a;O=b-w(b-m,b-n)if N then O=Q(O,N,...)end;return O elseif m then return m%a else return 0 end end;bit32.bor=Q;function bit32.btest(...)return P(...)~=0 end;function bit32.lrotate(B,z)return D(B%a,z)end;function bit32.rrotate(B,z)return A(B%a,z)end;function bit32.lshift(B,z)if z>31 or z<-31 then return 0 end;return x(B%a,z)end;
		function bit32.rshift(B,z)if z>31 or z<-31 then return 0 end;return y(B%a,z)end;function bit32.arshift(B,z)B=B%a;if z>=0 then if z>31 then return B>=0x80000000 and b or 0 else local O=y(B,z)if B>=0x80000000 then O=O+x(2^z-1,32-z)end;return O end else return x(B,-z)end end;function bit32.extract(B,G,...)local H=...or 1;if G<0 or G>31 or H<0 or G+H>32 then error'out of range'end;B=B%a;return E(B,G,...)end;
		function bit32.replace(B,i,G,...)local H=...or 1;if G<0 or G>31 or H<0 or G+H>32 then error'out of range'end;B=B%a;i=i%a;return I(B,i,G,...)end end


	-- SafeteeWoW/LibDeflate, GitHub

	--[[zlib License

	(C) 2018-2021 Haoqian He
	
	This software is provided 'as-is', without any express or implied
	warranty.  In no event will the authors be held liable for any damages
	arising from the use of this software.

	Permission is granted to anyone to use this software for any purpose,
	including commercial applications, and to alter it and redistribute it
	freely, subject to the following restrictions:

	1. The origin of this software must not be misrepresented; you must not
	   claim that you wrote the original software. If you use this software
	   in a product, an acknowledgment in the product documentation would be
	   appreciated but is not required.
	2. Altered source versions must be plainly marked as such, and must not be
	   misrepresented as being the original software.
	3. This notice may not be removed or altered from any source distribution.
	
	(dorpg modified the code only slightly)]]


	do LibDeflate = {}local b=LibDeflate;local assert=assert;local error=error;local pairs=pairs;local c=string.byte;local d=string.char;local e=string.sub;local f=table.concat;local tostring=tostring;local type=type;local g={}local h={}local i={}local j={3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258}local k={0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0}local l={[0]=1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577}local m={[0]=0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13}local n={16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15}local o;local p;local q;local r;local s;local t;for u=0,255 do h[u]=d(u)end;do local v=1;for u=0,32 do g[u]=v;v=v*2 end end;for u=1,9 do i[u]={}for w=0,g[u+1]-1 do local x=0;local y=w;for z=1,u do x=x-x%2+((x%2==1 or y%2==1)and 1 or 0)y=(y-y%2)/2;x=x*2 end;i[u][w]=(x-x%2)/2 end end;function b:Adler32(A)if type(A)~="string"then error(("!"):format(type(A)),2)end;local B=#A;local u=1;local C=1;local D=0;while u<=B-15
			do local E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T=c(A,u,u+15)D=(D+16*C+16*E+15*F+14*G+13*H+12*I+11*J+10*K+9*L+8*M+7*N+6*O+5*P+4*Q+3*R+2*S+T)%65521;C=(C+E+F+G+H+I+J+K+L+M+N+O+P+Q+R+S+T)%65521;u=u+16 end;while u<=B do local U=c(A,u,u)C=(C+U)%65521;D=(D+C)%65521;u=u+1 end;return(D*65536+C)%4294967296 end;local function V(W,X)return W%4294967296==X%4294967296 end;function b:CreateDictionary(A,B,Y)if type(A)~="string"then error(("!"):format(type(A)),2)end;if type(B)~="number"then error(("!"):format(type(B)),2)end;if type(Y)~="number"then error(("!"):format(type(Y)),2)end;if B~=#A then error(("!"):format(B,#A))end;if B==0 then error("!",2)end;if B>32768 then error(("!"):format(B),2)end;local Z=self:Adler32(A)if not V(Y,Z)then error(("!"):format(Y,Z))end;local _a={}_a.adler32=Y;_a.hash_tables={}_a.string_table={}_a.strlen=B;local a0=_a.string_table;local a1=_a.hash_tables;a0[1]=c(A,1,1)a0[2]=c(A,2,2)if B>=3 then local u=1;local a2=a0[1]*256+a0[2]while u<=B-2-3 do local E,F,G,H=c(A,u+2,u+5)a0[u+2]=E;a0[u+3]=F;a0[u+4]=G;a0[u+5]=H;a2=(a2*256+E)%16777216;local a3=a1[a2]if not a3 then a3={}a1[a2]=a3 end;a3[#a3+1]=u-B;u=u+1;a2=(a2*256+F)%16777216;a3=a1[a2]
					if not a3 then a3={}a1[a2]=a3 end;a3[#a3+1]=u-B;u=u+1;a2=(a2*256+G)%16777216;a3=a1[a2]if not a3 then a3={}a1[a2]=a3 end;a3[#a3+1]=u-B;u=u+1;a2=(a2*256+H)%16777216;a3=a1[a2]if not a3 then a3={}a1[a2]=a3 end;a3[#a3+1]=u-B;u=u+1 end;while u<=B-2 do local U=c(A,u+2)a0[u+2]=U;a2=(a2*256+U)%16777216;local a3=a1[a2]if not a3 then a3={}a1[a2]=a3 end;a3[#a3+1]=u-B;u=u+1 end end;return _a end;local function a4(_b)if type(_b)~="table"then return false,("'dictionary' - table expected got '%s'."):format(type(_b))end;if type(_b.adler32)~="number"or type(_b.string_table)~="table"or type(_b.strlen)~="number"or _b.strlen<=0 or _b.strlen>32768 or _b.strlen~=#_b.string_table or type(_b.hash_tables)~="table"then return false,("'dictionary' - corrupted dictionary."):format(type(_b))end;return true,""end;local a5={[0]={false,nil,0,0,0},[1]={false,nil,4,8,4},[2]={false,nil,5,18,8},[3]={false,nil,6,32,32},[4]={true,4,4,16,16},[5]={true,8,16,32,32},[6]={true,8,16,128,128},[7]={true,8,32,128,256},[8]={true,32,128,258,1024},[9]={true,32,258,258,4096}}local function a6(A,a7,_c,a8,a9)if type(A)~="string"then
				return false,("'str' - string expected got '%s'."):format(type(A))end;if a7 then local aa,ab=a4(_c)if not aa then return false,ab end end;if a8 then local ac=type(a9)if ac~="nil"and ac~="table"then return false,("'configs' - nil or table expected got '%s'."):format(type(a9))end;if ac=="table"then for ad,ae in pairs(a9)do if ad~="level"and ad~="strategy"then return false,("'configs' - unsupported table key in the configs: '%s'."):format(ad)elseif ad=="level"and not a5[ae]then return false,("'configs' - unsupported 'level': %s."):format(tostring(ae))elseif ad=="strategy"and ae~="fixed"and ae~="huffman_only"and ae~="dynamic"then return false,("'configs' - unsupported 'strategy': '%s'."):format(tostring(ae))end end end end;return true,""end;local function ap(aq)local ar=aq;local as=#aq;local at=1;local au=0;local av=0;local function aw(an)local ax=g[an]local ay;
				if an<=au then ay=av%ax;av=(av-ay)/ax;au=au-an else local az=g[au]local aA,aB,aC,aD=c(ar,at,at+3)av=av+((aA or 0)+(aB or 0)*256+(aC or 0)*65536+(aD or 0)*16777216)*az;at=at+4;au=au+32-an;ay=av%ax;av=(av-ay)/ax end;return ay end;local function aE(aF,aG,aH)assert(au%8==0)local aI=au/8<aF and au/8 or aF;for z=1,aI do local aJ=av%256;aH=aH+1;aG[aH]=d(aJ)av=(av-aJ)/256 end;au=au-aI*8;aF=aF-aI;if(as-at-aF+1)*8+au<0 then return-1 end;for u=at,at+aF-1 do aH=aH+1;aG[aH]=e(ar,u,u)end;at=at+aF;return aH end;local function aK(aL,aM,aN)local ay=0;local aO=0;local aP=0;local aQ;if aN>0 then if au<15 and ar then local az=g[au]local aA,aB,aC,aD=c(ar,at,at+3)av=av+((aA or 0)+(aB or 0)*256+(aC or 0)*65536+(aD or 0)*16777216)*az;at=at+4;au=au+32 end;local ax=g[aN]au=au-aN;ay=av%ax;av=(av-ay)/ax;ay=i[aN][ay]aQ=aL[aN]if ay<aQ then return aM[ay]end;aP=aQ;aO=aQ*2;ay=ay*2 end;for an=aN+1,15 do local aR;aR=av%2;av=(av-aR)/2;au=au-1;ay=aR==1 and ay+1-ay%2 or ay;aQ=aL[an]or 0;local aS=ay-aO;if aS<aQ then return aM[aP+aS]end;aP=aP+aQ;aO=aO+aQ;aO=aO*2;ay=ay*2 end;return-10 end;
			local function aT()return(as-at+1)*8+au end;local function aU()local aV=au%8;local ax=g[aV]au=au-aV;av=(av-av%ax)/ax end;return aw,aE,aK,aT,aU end;local function aW(A,_d)local aw,aE,aK,aT,aU=ap(A)local aX={ReadBits=aw,ReadBytes=aE,Decode=aK,ReaderBitlenLeft=aT,SkipToByteBoundary=aU,buffer_size=0,buffer={},result_buffer={},dictionary=_d}return aX end;local function aY(aZ,ai,aj)local aL={}local aN=aj;for ao=0,ai do local an=aZ[ao]or 0;aN=an>0 and an<aN and an or aN;aL[an]=(aL[an]or 0)+1 end;if aL[0]==ai+1 then return 0,aL,{},0 end;local a_=1;for b0=1,aj do a_=a_*2;a_=a_-(aL[b0]or 0)if a_<0 then return a_ end end;local b1={}b1[1]=0;for b0=1,aj-1 do b1[b0+1]=b1[b0]+(aL[b0]or 0)end;local aM={}for ao=0,ai do local an=aZ[ao]or 0;if an~=0 then local b2=b1[an]aM[b2]=ao;b1[an]=b1[an]+1 end end;return a_,aL,aM,aN end;local function b3(aX,b4,b5,b6,b7,b8,b9)local aG,aH,aw,aK,aT,ba=aX.buffer,aX.buffer_size,aX.ReadBits,aX.Decode,aX.ReaderBitlenLeft,aX.result_buffer;local _e=aX.dictionary;local bb;local bc;local bd=1;if _e and not aG[0]then bb=_e.string_table;bc=_e.strlen;bd=-bc+1;
				for u=0,-bc+1<-257 and-257 or-bc+1,-1 do aG[u]=h[bb[bc+u]]end end;repeat local ao=aK(b4,b5,b6)if ao<0 or ao>285 then return-10 elseif ao<256 then aH=aH+1;aG[aH]=h[ao]elseif ao>256 then ao=ao-256;local an=j[ao]an=ao>=8 and an+aw(k[ao])or an;ao=aK(b7,b8,b9)if ao<0 or ao>29 then return-10 end;local be=l[ao]be=be>4 and be+aw(m[ao])or be;local bf=aH-be+1;if bf<bd then return-11 end;if bf>=-257 then for z=1,an do aH=aH+1;aG[aH]=aG[bf]bf=bf+1 end else bf=bc+bf;for z=1,an do aH=aH+1;aG[aH]=h[bb[bf]]bf=bf+1 end end end;if aT()<0 then return 2 end;if aH>=65536 then ba[#ba+1]=f(aG,"",1,32768)for u=32769,aH do aG[u-32768]=aG[u]end;aH=aH-32768;aG[aH+1]=nil end until ao==256;aX.buffer_size=aH;return 0 end;local function bg(aX)local aG,aH,aw,aE,aT,aU,ba=aX.buffer,aX.buffer_size,aX.ReadBits,aX.ReadBytes,aX.ReaderBitlenLeft,aX.SkipToByteBoundary,aX.result_buffer;aU()local aF=aw(16)if aT()<0 then return 2 end;local bh=aw(16)if aT()<0 then return 2 end;if aF%256+bh%256~=255 then return-2 end;if(aF-aF%256)/256+(bh-bh%256)/256~=255 then return-2 end;
			aH=aE(aF,aG,aH)if aH<0 then return 2 end;if aH>=65536 then ba[#ba+1]=f(aG,"",1,32768)for u=32769,aH do aG[u-32768]=aG[u]end;aH=aH-32768;aG[aH+1]=nil end;aX.buffer_size=aH;return 0 end;local function bi(aX)return b3(aX,q,o,7,t,r,5)end;local function bj(aX)local aw,aK=aX.ReadBits,aX.Decode;local bk=aw(5)+257;local bl=aw(5)+1;local bm=aw(4)+4;if bk>286 or bl>30 then return-3 end;local bn={}for u=1,bm do bn[n[u]]=aw(3)end;local bo,bp,bq,br=aY(bn,18,7)if bo~=0 then return-4 end;local b4={}local b7={}local aP=0;while aP<bk+bl do local ao;local an;ao=aK(bp,bq,br)if ao<0 then return ao elseif ao<16 then if aP<bk then b4[aP]=ao else b7[aP-bk]=ao end;aP=aP+1 else an=0;if ao==16 then if aP==0 then return-5 end;if aP-1<bk then an=b4[aP-1]else an=b7[aP-bk-1]end;ao=3+aw(2)elseif ao==17 then ao=3+aw(3)else ao=11+aw(7)end;if aP+ao>bk+bl then return-6 end;while ao>0 do ao=ao-1;if aP<bk then b4[aP]=an else b7[aP-bk]=an end;aP=aP+1 end end end;if(b4[256]or 0)==0 then return-9 end;local bs,bt,b5,b6=aY(b4,bk-1,15)if not bt or bs~=0 and(bs<0 or bk~=(bt[0]or 0)+(bt[1]or 0))then return-7 end;
			local bu,bv,b8,b9=aY(b7,bl-1,15)if not bv or bu~=0 and(bu<0 or bl~=(bv[0]or 0)+(bv[1]or 0))then return-8 end;return b3(aX,bt,b5,b6,bv,b8,b9)end;local function bw(aX)local aw=aX.ReadBits;local bx;while not bx do bx=aw(1)==1;local by=aw(2)local bz;if by==0 then bz=bg(aX)elseif by==1 then bz=bi(aX)elseif by==2 then bz=bj(aX)else return nil,-1 end;if bz~=0 then return nil,bz end end;aX.result_buffer[#aX.result_buffer+1]=f(aX.buffer,"",1,aX.buffer_size)local bA=f(aX.result_buffer)return bA end;local function bB(A,_f)local aX=aW(A,_f)local bA,bz=bw(aX)if not bA then return nil,bz end;local bC=aX.ReaderBitlenLeft()local bD=(bC-bC%8)/8;return bA,bD end;local function bE(A,_g)local aX=aW(A,_g)local aw=aX.ReadBits;local bF=aw(8)if aX.ReaderBitlenLeft()<0 then return nil,2 end;local bG=bF%16;local bH=(bF-bG)/16;if bG~=8 then return nil,-12 end;if bH>7 then return nil,-13 end;local bI=aw(8)if aX.ReaderBitlenLeft()<0 then return nil,2 end;if(bF*256+bI)%31~=0 then return nil,-14 end;local bJ=(bI-bI%32)/32%2;local bK=(bI-bI%64)/64%4;if bJ==1 then if not _g then return nil,-16 end;
				local aC=aw(8)local aB=aw(8)local aA=aw(8)local bL=aw(8)local Z=aC*16777216+aB*65536+aA*256+bL;if aX.ReaderBitlenLeft()<0 then return nil,2 end;if not V(Z,_g.adler32)then return nil,-17 end end;local bA,bz=bw(aX)if not bA then return nil,bz end;aX.SkipToByteBoundary()local bM=aw(8)local bN=aw(8)local bO=aw(8)local bP=aw(8)if aX.ReaderBitlenLeft()<0 then return nil,2 end;local bQ=bM*16777216+bN*65536+bO*256+bP;local bR=b:Adler32(bA)if not V(bQ,bR)then return nil,-15 end;local bC=aX.ReaderBitlenLeft()local bD=(bC-bC%8)/8;return bA,bD end;function b:DecompressDeflate(A)local bS,bT=a6(A)if not bS then error("!"..bT,2)end;return bB(A)end;function b:DecompressDeflateWithDict(A,_h)local bS,bT=a6(A,true,_h)if not bS then error("!"..bT,2)end;return bB(A,_h)end;function b:DecompressZlib(A)local bS,bT=a6(A)if not bS then error("!"..bT,2)end;return bE(A)end;function b:DecompressZlibWithDict(A,_a)local bS,bT=a6(A,true,_a)if not bS then error("!"..bT,2)end;return bE(A,_a)end;do p={}for bU=0,143 do p[bU]=8 end;for bU=144,255 do p[bU]=9 end;for bU=256,279 do p[bU]=7 end;for bU=280,287 do p[bU]=8 end;s={}for be=0,31 do s[be]=5 end;
			local bz;bz,q,o=aY(p,287,9)assert(bz==0)bz,t,r=aY(s,31,5)assert(bz==0)end end


	-- Weldify's Signal Class
	do SignalConnection,Signal={},{};SignalConnection.__index,Signal.__index=SignalConnection,Signal;SignalConnection.ClassName,Signal.ClassName="SignalConnection","Signal"
		function SignalConnection.new(b,c,d)return setmetatable({_container=b,_index=c,_handler=d},SignalConnection)end;
		function SignalConnection:Disconnect()if self._container then self._container[self._index]=nil end end;
		function Signal.new()return setmetatable({_waits={},_handlers={}},Signal)end;
		function Signal:Fire(...)for f,g in ipairs(self._waits)do coroutine.resume(g,...)table.remove(self._waits,f)end;for f,g in pairs(self._handlers)do local h=coroutine.create(g._handler)coroutine.resume(h,...)end end;
		function Signal:Connect(d)assert(type(d)=="function","Passed value is not a function")local c=#self._handlers+1;local i=SignalConnection.new(self._handlers,c,d)table.insert(self._handlers,c,i)return i end;
		function Signal:Wait()table.insert(self._waits,coroutine.running())return coroutine.yield()end;
		function Signal:Destroy()for f,g in ipairs(self._waits)do coroutine.resume(g)table.remove(self._waits,f)end;for f,i in pairs(self._handlers)do i:Disconnect()end end end


	-- dumb thing I wrote myself
	do WOSscreenEmulator = {}
		WOSscreenEmulator.screenObjectClass={GUIObject=nil}
		WOSscreenEmulator.screenClass={SurfaceGUI=nil}
		function WOSscreenEmulator.screenObjectClass:new(b)b=b or {}setmetatable(b,self)self.__index=self;return b end
		function WOSscreenEmulator.screenObjectClass:AddChild(c)c.GUIObject.Parent=self.GUIObject;return end;
		function WOSscreenEmulator.screenObjectClass:Destroy()self.GUIObject:Destroy()return end;
		function WOSscreenEmulator.screenObjectClass:ChangeProperties(d)for e,f in d do self.GUIObject[e]=f end;return end;

		function WOSscreenEmulator.screenClass:new(b)b=b or{}setmetatable(b,self)self.__index=self;return b end;
		function WOSscreenEmulator.screenClass:CreateElement(g,d)local h=Instance.new(g)for e,f in d do h[e]=f end;h.Parent=self.SurfaceGUI;if#self.SurfaceGUI:GetDescendants()>1000 then print("!LIMIT REACHED!")return end;return WOSscreenEmulator.screenObjectClass:new({GUIObject=h})end;
		function WOSscreenEmulator.screenClass:GetDimensions()return self.SurfaceGUI.AbsoluteSize end end
end
-- Other Libraries, Classes and Functions
local sUnpackIter, createScreenObject, Renderer, UndoFilter, b64Decode, dump
local vector2x4Table = {}
do
	function dump(o)
		if type(o) == 'table' then
			local s = '{ '
			for k,v in pairs(o) do
				if type(k) ~= 'number' then k = '"'..k..'"' end
				s = s .. '['..k..'] = ' .. dump(v) .. ','
			end
			return s .. '} '
		else
			return tostring(o)
		end
	end

	createScreenObject = function(className, parent, properties)
		if type(parent)=="string" then parent = subScreen[parent] end

		local obj=nil
		for _,bScreen in next,buildScreens do
			obj = bScreen:CreateElement(className, properties)
			if obj then break end
		end

		assert(obj,[[cSO encountered an error:
		nil.]])
		parent:AddChild(obj)
		return obj
	end

	sUnpackIter = function(format:string, toUnpack:string)
		local strLen,p = #toUnpack,1
		return function()
			if p>strLen then return nil end
			local r = {sUnpack(format,toUnpack,p)}; p = remove(r)
			return table.unpack(r)
		end
	end

	Renderer = {}

	function Renderer.new(rChunkX:number,rChunkY:number)
		local label1,label2 = createScreenObject("ImageLabel", rendererFrame, Renderer.getInitPDict(rChunkX*2-1,rChunkY)),
			createScreenObject("ImageLabel", rendererFrame, Renderer.getInitPDict(rChunkX*2,rChunkY));
		return setmetatable({label1,label2},{__call=Renderer.set2PropertiesFunction('ImageRectOffset',label1,label2)})
	end

	function Renderer.getInitPDict(cX,cY)
		return{
			Position=UDim2.fromScale(cSizeS.x*(cX),cSizeS.y*(cY)),
			Size=UDim2.fromScale(cSizeS.x,cSizeS.y),
			ResampleMode=1,
			ScaleType=2,
			TileSize=UDim2.new(1,0,1,0),
			BackgroundColor3=Color3.new(0,0,0),
			Image=pImages.normal,
			BorderSizePixel=0,
			Name=cX.." - "..cY,
			ImageRectSize = Vector2.new(4,4),
			ImageRectOffset = Vector2.new(0,0),
		}
	end
	
	function Renderer.setPropertiesFunction(propertyName,...)
		local screenObjects={...}
		local __newindex=getmetatable(screenObjects[1]).__newindex
		return function(valueT)
			for k,v in next,valueT do
				__newindex(screenObjects[k],propertyName,v)
			end
		end
	end
	
	function Renderer.set2PropertiesFunction(propertyName,o1,o2)
		local __newindex=getmetatable(o1).__newindex
		return function(vT)
			__newindex(o1,propertyName,vT[1])
			__newindex(o2,propertyName,vT[2])
		end
	end
	
	
	local uFilterFunctions = {
		[1]=function(rcSl,_)

		end;
		[2]=function(rcSl,pSl)
		end;
	}

	function undoFilter(method, rcSl, pSl) --result scanline Is the current scanline
		-- local filterUnit = 2 --number of bytes in each chunk, therefore the increment

		if method==0 then return rcSl

		elseif method==1 then
			for i=1,#rcSl do
				rcSl[i]=(rcSl[i]+(rcSl[i-2] or 0))%256
			end

		elseif method==2 then
			if not pSl then return rcSl end

			for i=1,#rcSl do
				rcSl[i]=(rcSl[i]+(pSl[i]))%256
			end
		end

		return rcSl
	end

	for x=0,255 do
		for y=0,255 do
			vector2x4Table[x*256+y]=Vector2.new(x*4,y*4)
		end
	end
end

local function InitGUI()
	print("Initializing GUI")

	decor = {}
	local mScreenDimV2 = screens["mainScreen"]:GetDimensions()
	mSSize.x,mSSize.y=mScreenDimV2.X,mScreenDimV2.Y;mSSize.r=mSSize.x/mSSize.y

	if mSSize.r>aRatio then
		rFSize={x=mSSize.y*aRatio,y=mSSize.y}
	else
		rFSize={x=mSSize.x,y=mSSize.x/aRatio}
	end

	rCSize={x=rFSize.x/widthInRChunks, y=rFSize.y/heightInRChunks}
	cSize={x=rFSize.x/widthInChunks, y=rFSize.y/heightInChunks}
	cSizeS={x=4/metadata.width,y=4/metadata.height}

	rendererFrame = createScreenObject("Frame", 'mainScreen', {
		Name = "Bad Apple!",
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, rFSize.x, 0, rFSize.y),
		ClipsDescendants = true,
		BackgroundTransparency = 1,
	})

	progressFrame = createScreenObject("Frame", 'mainScreen', {
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, math.min(rFSize.x,rFSize.y)*0.8, 0, math.min(rFSize.x,rFSize.y)*0.8),
		ZIndex = 10,
		SizeConstraint = 2,
		BackgroundTransparency = 1})




	local progressText = createScreenObject("TextLabel", progressFrame, {
		AnchorPoint = Vector2.new(0.5,0.5),
		Position = UDim2.fromScale(0.5,0.5),
		Size = UDim2.fromScale(0.3,0.1),
		ZIndex = 17,
		BackgroundTransparency = 1,
		TextScaled = true,
		TextColor3=Color3.new(1,1,1),
		Text="Initializing..."
	})

	local function radProImg(ZIndex, width, sheetID)
		return createScreenObject("ImageLabel", progressFrame, {
			AnchorPoint = Vector2.new(0.5,0.5),
			Position = UDim2.fromScale(0.5,0.5),
			Size = UDim2.fromScale(width,width),
			Image = ("rbxassetid://%s"):format(sheetID),
			BackgroundTransparency = 1,
			ZIndex = ZIndex,
			ImageRectSize = Vector2.new(64, 64),
			ImageRectOffset = Vector2.new(0, 0),
		})
	end

	for zI,p in {[12]={s=0.66,c=0}, [14]={s=0.52,c=0.175}, [16]={s=0.35,c=0.25}} do
		insert(decor, createScreenObject("ImageLabel", progressFrame, {
			AnchorPoint = Vector2.new(0.5,0.5),
			Size = UDim2.fromScale(p.s,p.s),
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = "rbxassetid://12206409737",
			ImageColor3=Color3.new(p.c+0.2,p.c,p.c),
			ZIndex = zI
		}))
	end

	local progressLabels = {
		read = radProImg(11, 0.8, "14905006959"),
		decode = radProImg(13, 0.65, "14905005403"),
		construct = radProImg(15, 0.5, "14905004346"),
	}

	function updateProgress(toUpdate:string, ratio:number, centerText:string?)
		centerText = centerText or nil
		ratio = ratio or 1
		if toUpdate=="demoman" then progressFrame:Destroy() return end

		print(ratio)
		local spriteI = (ratio-math.floor(ratio))*256
		progressLabels[toUpdate].ImageRectOffset = Vector2.new(math.floor(spriteI%16)*64, math.floor(spriteI/16)*64)
		if centerText then
			progressText:ChangeProperties({Text=centerText})
		end
	end
end

do
	screens = {}

	if not GetPartFromPort then GetPartFromPort,GetPartsFromPort,Beep,TriggerPort = nil,nil,nil,nil end
	screens["mainScreen"] = GetPartFromPort(1, "Screen")
	buildScreens = GetPartsFromPort(2, "Screen")

	for _,screen in screens do screen:ClearElements() end
	for _,bScreen in next,buildScreens do bScreen:ClearElements() end

	subScreen = {}
	for screenName,screen in screens do
		subScreen[screenName] = screen:CreateElement("Frame", {Name="subScreen", Size=UDim2.fromScale(1,1), BackgroundTransparency=1})
	end

	print("Attempting Download")

	for k,v in metadata do
		print(k.." - "..v)
	end

	aRatio = metadata.width/metadata.height

	widthInChunks = ceil(metadata.width/4)
	heightInChunks = ceil(metadata.height/4)

	widthInRChunks = ceil(widthInChunks/2)
	heightInRChunks = heightInChunks



	InitGUI()

	local renderers = {}
	for rChunkX=1,widthInRChunks do
		renderers[rChunkX]={}
		print("Building Screen Object: "..tostring(rChunkX)*heightInRChunks)
		for rChunkY=1,heightInRChunks do

			--renderers[rChunkX][rChunkY] = coroutine.wrap(InitRendererChunkA)
			--renderers[rChunkX][rChunkY](nil,rChunkX,rChunkY)

			local s = Renderer:new(rChunkX,rChunkY)
		end
		if rChunkX%2==0 then task.wait() end
	end


	local renderFrames = nil

	do
		local k,j=renderers,vector2x4Table
		--insertMarker_renderFrames
	end

	if not renderFrames then
		assert(fileStringGet, "Please insert cash or payment type.")
		local file = fileStringGet()

		metadata = {
			["width"] = sUnpack(">I2",file,1),
			["height"] = sUnpack(">I2",file,3),
			["frameCount"] = sUnpack(">I3",file,5),
			["fps"] = sUnpack(">I1",file,8),
		}

		local framesData = {}

		local processedCount = 0
		local processCoroutines = {}

		compressedPackets = {}
		local read,pointer = "",9
		while pointer<=#file do
			read,pointer = sUnpack(">s4",file,pointer)
			task.wait()
			insert(processCoroutines,task.spawn(function(toDecomp)
				local success, err = pcall(function()

					for frameI,frameD in sUnpackIter(">I2s2",LibDeflate:DecompressZlib(toDecomp)) do
						frameI+=1
						if #frameD==0 then
							framesData[frameI]={frameFormat=1}
						else
							framesData[frameI] = {frameFormat=0,scanlines={}}

							local pointer3 = 1
							for slY=1,heightInChunks do
								local resultSl,slBytes={zPaddedSlBytes=create(widthInChunks*2,0)},nil
								resultSl.filterMethod,slBytes,pointer3=sUnpack(">I1s2",frameD,pointer3)
								for cB in string.gmatch(slBytes,"....") do
									local cI,cB1,cB2=sUnpack(">I2I1I1",cB)
									resultSl.zPaddedSlBytes[cI*2-1],resultSl.zPaddedSlBytes[cI*2]=cB1,cB2
								end
								framesData[frameI].scanlines[slY]=resultSl
							end
							task.wait()
						end
						processedCount+=1
						if processedCount%10==0 then
							updateProgress("read", processedCount/metadata.frameCount, "Reading file...")
						end
					end
				end)
				if not success then print("Failed, Error: "..err);--[[Beep(0.75)]]
				else print("Success");--[[Beep(1.25)]]end
			end, read))
		end

		repeat
			for k,v in pairs(processCoroutines) do
				if coroutine.status(v)=="dead" then
					remove(processCoroutines,k)
				end
				task.wait()
			end
		until #processCoroutines==0

		file = nil
		updateProgress("read", 0.999)

		local lChunk1,lChunk2 = {},{}
		for y=1,heightInRChunks do
			lChunk1[y],lChunk2[y]={},{}
			for x=1,widthInRChunks do
				lChunk1[y][x],lChunk2[y][x]=0,0
			end
		end

		for frameI,frame in pairs(framesData) do
			if frame.frameFormat ~= 0 then continue end
			renderFrames[frameI] = {}


			local builtScanline
			for rCY,slData in pairs(frame.scanlines) do
				builtScanline = undoFilter(slData.filterMethod,slData.zPaddedSlBytes,builtScanline)

				for rCX=1,widthInChunks/2 do
					local chunk1,chunk2 = builtScanline[rCX*4-3]*256+builtScanline[rCX*4-2],builtScanline[rCX*4-1]*256+builtScanline[rCX*4]

					if chunk1+chunk2~=0 then
						lChunk1[rCY][rCX],lChunk2[rCY][rCX] = bit32.bxor(chunk1,lChunk1[rCY][rCX]),bit32.bxor(chunk2,lChunk2[rCY][rCX])
						insert(renderFrames[frameI],{
							renderers[rCX][rCY].label1,
							renderers[rCX][rCY].label2,
							Vector2.new(
								(lChunk1[rCY][rCX]%256)*4,
								fdiv(lChunk1[rCY][rCX],256)*4),
							Vector2.new(
								(lChunk2[rCY][rCX]%256)*4,
								fdiv(lChunk2[rCY][rCX],256)*4)})
					end
				end
			end
			if frameI%10==0 then
				task.wait()
				updateProgress("decode", frameI/metadata.frameCount, "Decoding file...")
			end
		end
	end
	updateProgress("decode", 0.999)
	local batchSize = 512

	local renderCoros,frameI = {},0



	for frameI,renderChunks in next,renderFrames do
		insert(renderCoros, frameI, coroutine.create(function()
			local coroI = frameI;local renderChunks = renderChunks

			


			for batchI = 1, ceil(#renderChunks/batchSize) do
				local sI,eI = (batchI-1)*batchSize+1,min(batchSize*batchSize,#renderChunks)

				task.spawn(function()
					task.wait(frameI/metadata.fps)
					for cI=sI,eI do
						local renderChunk = renderChunks[cI]
						renderChunk[1].ImageRectOffset = renderChunk[2]
						renderChunk[3].ImageRectOffset = renderChunk[4]
					end
				end)
			end


			renderCoros[coroI] = nil

		end))
		if frameI%50==0 then
			task.wait()
			updateProgress("construct", frameI/metadata.frameCount, "Constructing Frames...")
		end
	end
	updateProgress("construct", 0.999, "Finishing up...")
	for _,c in pairs(renderCoros) do
		coroutine.resume(c)
	end
	updateProgress("demoman")
	for _,v in next,GetPartsFromPort(35,"Speaker") do v:ClearSounds() end
	do
		local disk=GetPartFromPort(35,"Disk")
		for _,v in pairs(disk:Read('midiCoroutines')) do coroutine.resume(v) end
		disk:Write('midiCoroutines', nil)
	end

	task.wait(metadata.frameCount/metadata.fps+2)
	print("EOF")
end