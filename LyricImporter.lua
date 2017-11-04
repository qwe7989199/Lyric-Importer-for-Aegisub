--[[ This script is used to convert the special format lyric file of Kugou Music (.krc) , QQ Music (.qrc) and LyRiCs (.lrc) into ASS format.
You could get these lyric files from the software above or foobar2000 with "ESLyric" plugin.
--]]

local tr = aegisub.gettext
script_name = tr"Import Lyric File"
script_description = tr"Import Lyric File For Aegisub"
script_author = "domo&SuJiKiNen"
script_version = "1.3"

k_tag="\\K"  --you can change this to \\k or \\kf
NOT_SET_ENDTIME = -1

local json = require"json"
local ffi  = require('ffi')
ffi.load("QQMusicCommon.dll")
local lyric_decoder = ffi.load("LyricDecoder.dll")

ffi.cdef[[
char *krcdecode(char *src, int src_len);
char *qrcdecode(char *src, int src_len);
void free(void *memblock);
]]

isstring = function(s)
if type(s) == "string" then
end
end
table.tostring = function(t)
assert(type(t), "table")
local result, result_n = {}, 0
local function convert_recursive(t, space)
  for key, value in pairs(t) do
	result_n = result_n + 1
	result[result_n] = ("%s[%s] = %s"):format(space,
											  isstring(key) and ("%q"):format(key) or key,
											  isstring(value) and ("%q"):format(value) or value)
	if type(value) == "table" then
	  convert_recursive(value, space .. "\t")
	end
  end
end
convert_recursive(t, "")
return table.concat(result, "\n")
end
bit = require("bit")

local ffi = require'ffi'
local bit = require'bit'
local rshift = bit.rshift
local lshift = bit.lshift
local bor = bit.bor
local band = bit.band
local floor = math.floor

local mime64chars = ffi.new("uint8_t[64]",
"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")
local mime64lookup = ffi.new("uint8_t[256]")
ffi.fill(mime64lookup, 256, 0xFF)
for i=0,63 do
mime64lookup[mime64chars[i]]=i
end

local u8arr= ffi.typeof'uint8_t[?]'
local u8ptr=ffi.typeof'uint8_t*'

--- Base64 decode a string or a FFI char *.
-- @param str (String or char*) Bytearray to decode.
-- @param sz (Number) Length of string to decode, optional if str is a Lua string
-- @return (String) Decoded string.
function base64_decode(str, sz)
if (type(str)=="string") and (sz == nil) then sz=#str end
local m64, b1 -- value 0 to 63, partial byte
local bin_arr = ffi.new(u8arr, floor(bit.rshift(sz*3,2)))
local mptr    = ffi.cast(u8ptr,bin_arr) -- position in binary mime64 output array
local bptr    = ffi.cast(u8ptr,str)
local i       = 0
while true do
	repeat
		if i >= sz then goto done end
		m64 = mime64lookup[bptr[i]]
		i=i+1
	until m64 ~= 0xFF -- skip non-mime characters like newlines
	b1=lshift(m64, 2)
	repeat
		if i >= sz then goto done end
		m64 = mime64lookup[bptr[i]]
		i=i+1
	until m64 ~= 0xFF -- skip non-mime characters like newlines
	mptr[0] = bor(b1,rshift(m64, 4)); mptr=mptr+1
	b1 = lshift(m64,4)
	repeat
		if i >= sz then goto done end
		m64 = mime64lookup[bptr[i]]
		i=i+1
	until m64 ~= 0xFF -- skip non-mime characters like newlines
	mptr[0] = bor(b1,rshift(m64, 2)); mptr=mptr+1
	b1 = lshift(m64,6)
	repeat
		if i >= sz then goto done end
		m64 = mime64lookup[bptr[i]]
		i=i+1
	until m64 ~= 0xFF -- skip non-mime characters like newlines
	mptr[0] = bor(b1, m64); mptr=mptr+1
end
::done::
return ffi.string(bin_arr, (mptr-bin_arr))
end


local function unicode_to_utf8(convertStr)
  if type(convertStr)~="string" then
  return convertStr
  end
local resultStr=""
  local i=1
while true do
  local num1=string.byte(convertStr,i)
	  local unicode
  if num1~=nil and string.sub(convertStr,i,i+1)=="\\u" then
		  unicode=tonumber("0x"..string.sub(convertStr,i+2,i+5))
		  i=i+6
  elseif num1~=nil then
		  unicode=num1
		  i=i+1
	  else
		  break
	  end
	  if unicode <= 0x007f then
		  resultStr=resultStr..string.char(bit.band(unicode,0x7f))
	  elseif unicode >= 0x0080 and unicode <= 0x07ff then
		  resultStr=resultStr..string.char(bit.bor(0xc0,bit.band(bit.rshift(unicode,6),0x1f)))
		  resultStr=resultStr..string.char(bit.bor(0x80,bit.band(unicode,0x3f)))
	  elseif unicode >= 0x0800 and unicode <= 0xffff then
		  resultStr=resultStr..string.char(bit.bor(0xe0,bit.band(bit.rshift(unicode,12),0x0f)))
		  resultStr=resultStr..string.char(bit.bor(0x80,bit.band(bit.rshift(unicode,6),0x3f)))
		  resultStr=resultStr..string.char(bit.bor(0x80,bit.band(unicode,0x3f)))
	  end
  end
resultStr=resultStr..'\0'
return resultStr
end

local function round(x, dec)
-- Check argument
if type(x) ~= "number" or dec ~= nil and type(dec) ~= "number" then
  error("number and optional number expected", 2)
end
-- Return number
if dec and dec >= 1 then
  dec = 10^math.floor(dec)
  return math.floor(x * dec + 0.5) / dec
else
  return math.floor(x + 0.5)
end
end

function filename_extension(filename)
if type(filename) ~= "string" then
  error("filename must be string")
end
return string.lower(string.sub(filename,-3,-1))
end

function ass_line_template()
line = {}
line.class = "dialogue"
line.raw = "Dialogue: 0,0:00:00.00,0:00:05.00,Default,,0,0,0,,"
line.section = "[Events]"
line.comment = false
line.layer = 0
line.start_time = 0
line.end_time = 5000
line.style = "Default"
line.margin_l,line.margin_r,line.margin_t,line.margin_b = 0,0,0,0
line.actor,line.effect,line.text  = " "," ",""
line.extra = {}
return line
end

function ass_simple_line(st,et,text,cmd_str)
line = ass_line_template()
line.start_time = st
line.end_time   = et
line.text       = text
if type(cmd_str) == "string" then
  load(cmd_str)()
end
return line
end

function krc_handler(encoded_str)
local convert_subtitles = {}
local encoded_c_str = ffi.new("char[?]", (#encoded_str)+1)
ffi.copy(encoded_c_str, encoded_str)
decoded_p = lyric_decoder.krcdecode(encoded_c_str,#encoded_str)
decoded_str = ""
if decoded_p then
  decoded_str = ffi.string(decoded_p)
  ffi.C.free(decoded_p)
end

syln = 0
for krc_line in string.gmatch(decoded_str,"%[%d+,%d+%][^%[]*") do
  ass_line = krc_parse_line(krc_line)
  table.insert(convert_subtitles,ass_line)
end    

--  This part is for romaji in Krc file
--  Ignore translation by default
language = string.match(decoded_str,"%[language:([^%]]+)")
lan_text = unicode_to_utf8(base64_decode(language))
str = json.decode(lan_text)
--aegisub.debug.out("Syllable Number："..tostring(syln).."\n")
for i=1,#str.content do --Language Number
  romaji = {}
  for j=1,#str.content[i].lyricContent do --Sentence Number
	 for k=1,#str.content[i].lyricContent[j] do  --Syllable Number
	  table.insert(romaji,tostring(str.content[i].lyricContent[j][k]))
	 end
  end
  --aegisub.debug.out("Romaji Number: "..tostring(#romaji).."\n")
  if #romaji == syln then
    romaji_all    = romaji
    dia_config    = {}
    dia_config[1] = {class="label",x=0,y=0,label="Romaji lyrics found. Add them ?",width=5}
    btn_roma, config = aegisub.dialog.display(dia_config,{"Yes", "No"})
  elseif #romaji == #str.content[i].lyricContent then  --This is translation 
    romaji        = {}
  	--trans         = romaji
    --dia_config    = {}
    --dia_config[1] = {class="label",x=0,y=0,label="Translation found. Add it ?",width=5}
    --btn_trans, config = aegisub.dialog.display(dia_config,{"Yes", "No"})
  else
  end
end
if btn_roma == "Yes" then
  i = 1
  for krc_line in string.gmatch(decoded_str,"%[%d+,%d+%][^%[]*") do
   ass_line = romaji_parse_line(krc_line,romaji_all)
   table.insert(convert_subtitles,ass_line)
  end
end

if btn_trans == "Yes" then
  i = 1
  for krc_line in string.gmatch(decoded_str,"%[%d+,%d+%][^%[]*") do
   ass_line = trans_parse_line(krc_line,trans)
   table.insert(convert_subtitles,ass_line)
  end
end
  return convert_subtitles
end


function romaji_parse_line(krc_line, romaji)
lst,ldur,syls_str = string.match(krc_line,"^%[(%d+),(%d+)%](.*)$")
let   = lst + ldur
ltext = ""

for t3,t4,syl_text in string.gmatch(syls_str,"<(%d+),(%d+),%d+>([^<]+)") do
  kdur     = round(t4/10)
  syl_text = string.gsub(romaji[i],"　",string.format("{%s%d}　",k_tag,"0"))
  syl_text = string.gsub(syl_text,"{"..k_tag.."0}[　 ]*[\n\r]*","")
  ltext    = ltext..string.format("{%s%d}",k_tag,kdur)..syl_text
  i        = i + 1
end
ltext = string.gsub(ltext,"[\n\r]*","")
return ass_simple_line(lst,let,ltext,"line.actor='Romaji'")
end

function trans_parse_line(krc_line, trans)
lst,ldur,syls_str = string.match(krc_line,"^%[(%d+),(%d+)%](.*)$")
let   = lst + ldur
ltext = trans[i]
i     = i + 1
return ass_simple_line(lst,let,ltext,"line.actor='Trans'")
end

function krc_parse_line(krc_line)
lst,ldur,syls_str = string.match(krc_line,"^%[(%d+),(%d+)%](.*)$")
let   = lst + ldur
ltext = ""

for t3,t4,syl_text in string.gmatch(syls_str,"<(%d+),(%d+),%d+>([^<]+)") do
  kdur     = round(t4/10)
  syl_text = string.gsub(syl_text,"　",string.format("{%s%d}　",k_tag,"0"))
  syl_text = string.gsub(syl_text,"{"..k_tag.."0}[　 ]*[\n\r]*","")
  ltext    = ltext..string.format("{%s%d}",k_tag,kdur)..syl_text
  syln     = syln + 1
end
ltext = string.gsub(ltext,"[\n\r]*","")
return ass_simple_line(lst,let,ltext)
end

function qrc_handler(encoded_str)
local convert_subtitles = {}
local encoded_c_str = ffi.new("char[?]", (#encoded_str)+1)
ffi.copy(encoded_c_str, encoded_str)
decoded_p   = lyric_decoder.qrcdecode(encoded_c_str,#encoded_str)
decoded_str = ""
if decoded_p then
  decoded_str = ffi.string(decoded_p)
  ffi.C.free(decoded_p)
end
aegisub.debug.out(decoded_str)
for qrc_line in string.gmatch(decoded_str,"%[%d+,%d+%][^%[]*") do
  ass_line = qrc_parse_line(qrc_line)
  table.insert( convert_subtitles,ass_line )
end
return convert_subtitles
end

function qrc_parse_line(qrc_line)
lst,ldur,syls_str = string.match(qrc_line,"%[(%d+),(%d+)%](.*)")
let   = lst + ldur
ltext = ""
for syl_text,t3,t4 in string.gmatch(syls_str,"([%(]?[^%(]*)%((%d+),(%d+)%)") do
  kdur     = round(t4/10)
  syl_text = string.gsub(syl_text,"[^}]　",string.format("{%s%d}　",k_tag,"0"))
  syl_text = string.gsub(syl_text,"{"..k_tag.."0}[　 ]*[\n]+","")
  ltext    = ltext..string.format("{%s%d}",k_tag,kdur)..syl_text
end
return ass_simple_line(lst,let,ltext)
end

function lrc_handler(lrc_strs)
convert_subtitles = {}
for lrc_line in string.gmatch(lrc_strs,"%[%d+:%d*[%.:]?%d-%][^\n]+") do
  lines = lrc_parse_line(lrc_line)
  for _,convert_line in ipairs(lines) do
	table.insert(convert_subtitles,convert_line)
  end
end
-- table.insert(convert_subtitles,ass_simple_line(3600000,0,""))
table.sort(convert_subtitles,function(a,b) return a.start_time<b.start_time end )
for i=#convert_subtitles-1,1,-1 do
  if convert_subtitles[i]["end_time"]==NOT_SET_ENDTIME then
	convert_subtitles[i]["end_time"] = convert_subtitles[i+1]["start_time"]
  end
end
return convert_subtitles
end

function lrc_time_2_ass_time(string)
min,sec,cs = string.match(string,"%[(%d+):(%d*)[%.:]?(%d-)%]")
min = tonumber(min) or 0
sec = tonumber(sec) or 0
cs  = tonumber(cs)  or 0
return min*60*1000 + sec*1000 + cs*10
end

function lrc_parse_line(lrc_line)
lines = {}
times = {}
parsed_data = {}
for time_str,text in string.gmatch(lrc_line,"(%[%d+:%d*[%.:]?%d-%])([^%[\r\n]*)") do
  table.insert(times,time_str)
  if text~="" then
	for _,time_str in ipairs(times) do
	  table.insert(parsed_data,{time_str=time_str,text=text})
	end
	times = {}
  end
end

if #times>0 then -- k timed lrc
  table.insert(parsed_data,{time_str=times[1],text=""})
  ass_line = ass_line_template()
  ass_line.start_time = lrc_time_2_ass_time(parsed_data[1]["time_str"])
  for i=2,#parsed_data do
	syl_start_time = lrc_time_2_ass_time(parsed_data[i-1]["time_str"])
	syl_end_time   = lrc_time_2_ass_time(parsed_data[i]["time_str"])
	syl_dur        = (syl_end_time - syl_start_time) / 10
	syl_text       = parsed_data[i-1]["text"]
	ass_line.text  = ass_line.text..string.format("{%s%d}%s",k_tag,syl_dur,syl_text)
  end
  ass_line.end_time = lrc_time_2_ass_time(parsed_data[#parsed_data]["time_str"])
  table.insert(lines,ass_line)
else -- normal line or merged same text lines
  for i=1,#parsed_data do
	ass_line = ass_simple_line(0,NOT_SET_ENDTIME,"")
	ass_line.start_time = lrc_time_2_ass_time(parsed_data[i]["time_str"])
	ass_line.text       = parsed_data[i]["text"]
	table.insert(lines,ass_line)
  end
end
return lines
end

function lyric_to_ass(subtitles)
local filename = aegisub.dialog.open('Select Lyric File',
									 '',
									 '',
									 'Supported Lyrics File(*.krc,*.qrc,*lrc)|*.krc;*.qrc;*lrc',
									 false,
									 true)
if not filename then
  aegisub.cancel()
end

local encoded_file = io.open(filename,"rb")
if not encoded_file then
  aegisub.debug.out("Failed to load encoded file")
  aegisub.cancel()
end
local encoded_str = encoded_file:read("*all")
encoded_file:close()

allow_ext   = { "krc","qrc","lrc" }
ext_handler = {
  krc = krc_handler,
  qrc = qrc_handler,
  lrc = lrc_handler,
}
import_file_ext = filename_extension(filename)
handler = ext_handler[import_file_ext]
convert_subtitles = handler(encoded_str)
if convert_subtitles then
  subtitles.append(unpack(convert_subtitles))
end
end

aegisub.register_macro(script_name, script_description, lyric_to_ass)
