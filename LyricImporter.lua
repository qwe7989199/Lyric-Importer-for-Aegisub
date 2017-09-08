--[[ This script is used to convert the special format lyric file of Kugou Music (.krc) , QQ Music (.qrc) and LyRiCs (.lrc) into ASS format.
  You could get these lyric files from the software above or foobar2000 with "ESLyric" plugin.
--]]

local tr = aegisub.gettext
script_name = tr"Import Lyric File"
script_description = tr"Import Lyric File For Aegisub"
script_author = "domo&SuJiKiNen"
script_version = "1.2"

k_tag="\\K"

local ffi = require('ffi')
ffi.load("QQMusicCommon.dll")
local lyric_decoder = ffi.load("LyricDecoder.dll")

ffi.cdef[[
  char *krcdecode(char *src, int src_len);
  char *qrcdecode(char *src, int src_len);
  void free(void *memblock);
  ]]

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
  return string.lower(string.sub(filename,-4,-1))
end

allow_ext   = { ".krc",".qrc","lrc" }
ext_handele = { krc_handle,qrc_handle,lrc_handle }

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

  -- aegisub.debug.out(tostring(#encoded_str).." ")
  -- aegisub.debug.out(tostring(string.len(encoded_str)).." ")
  local encoded_c_str = ffi.new("char[?]", (#encoded_str)+1)
  ffi.copy(encoded_c_str, encoded_str)

  import_file_ext = filename_extension(filename)
  if     import_file_ext == ".krc" then
    decoded_p = lyric_decoder.krcdecode(encoded_c_str,#encoded_str)
  elseif import_file_ext == ".qrc" then
    decoded_p = lyric_decoder.qrcdecode(encoded_c_str,#encoded_str)
  elseif import_file_ext == ".lrc" then
    lyric = io.open(filename,"r")
    if not lyric then
      aegisub.debug.out("Failed to load lrc file.")
      aegisub.cancel()
    end
    str = lyric:read("*a")  --read for karaoke lrc
    lyric:close()
    lyric = io.open(filename,"r")  --reread for omitted lrc
  end

  if decoded_p then
    decoded_str = ffi.string(decoded_p)
    ffi.C.free(decoded_p)
    str=decoded_str
  end
  encoded_file:close()
  l={}
  for j = 1, #subtitles do
    if subtitles[j].class == "dialogue" then
      l = subtitles[j]
      break
    end
  end

  --Krc to ASS

  if string.lower(string.sub(filename,-4,-1)) == ".krc" then
    for t1,t2,line_lyric in string.gmatch(str,"%[(%d+),(%d+)%]([^%[]*)") do
      if (t1~=nil and t2~=nil and line_lyric~=nil) then
        ls_t  = t1
        le_t  = t1+t2
        k_lrc = ""
        for t3,t4,syl_text in string.gmatch(line_lyric,"<(%d+),(%d+),%d+>([^<]+)") do
          kdur     = round(t4/10)
          syl_text = string.gsub(syl_text,"　",string.format("{%s%d}　[^\n]",k_tag,"0"))
          syl_text = string.gsub(syl_text,"[　 ]*[\n\r]+","")
          k_lrc    = k_lrc..string.format("{%s%d}",k_tag,kdur)..syl_text
        end
        l.start_time = ls_t
        l.end_time   = le_t
        l.text       = k_lrc
        subtitles[0] = l
      end
    end

   --Qrc to ASS

  elseif string.lower(string.sub(filename,-4,-1)) == ".qrc" then
    for t1,t2,line_lyric in string.gmatch(str,"%[(%d+),(%d+)%]([^%[]*)") do
      if (t1~=nil and t2~=nil and line_lyric~=nil) then
        ls_t  = t1
        le_t  = t1+t2
        k_lrc = ""
        for syl_text,t3,t4 in string.gmatch(line_lyric,"([^%(]*)%((%d+),(%d+)%)") do
          kdur     = round(t4/10)
          syl_text = string.gsub(syl_text,"　",string.format("{%s%d}　",k_tag,"0"))
          syl_text = string.gsub(syl_text,"[　 ]*[\n\r]+","")
          k_lrc    = k_lrc..string.format("{%s%d}",k_tag,kdur)..syl_text
        end
        l.start_time = ls_t
        l.end_time   = le_t
        l.text       = k_lrc
        subtitles[0] = l
      end
    end

    --Lrc to ASS

  elseif string.lower(string.sub(filename,-4,-1)) == ".lrc" then
    i=1
    ls_t  = {}
    le_t  = {}
    l_lrc = {}
    for st_min,st_sec,st_cs,line_lyric in string.gmatch(str,"%[(%d+):(%d+)%.(%d+)%]([^\n]+)") do --for karaoke timed lrc
      lrc_with_k = nil
      if (st_min == nil and st_sec == nil and st_cs == nil) then
        ls_t[i] = 0
      else
        ls_t[i]  = st_min*60*1000+st_sec*1000+st_cs*10
        l_lrc[i] = line_lyric
        if string.find(line_lyric,"[^%]]+%[(%d+):(%d+)%.(%d+)%]") ~= nil then --if the lrc contains karaoke time like [00:00.00]syl[00:00.50]
          lrc_with_k = true
          kdur = 0
          total_prev_k = 0
          k_lrc = {}
          k_lrc[i] = ""
          for syl_text,sst_min,sst_sec,sst_cs in string.gmatch(line_lyric,"([^%[]+)%[(%d+):(%d+)%.(%d+)%]") do
            total_prev_k = total_prev_k + kdur
            kdur = round(((sst_min*60*1000+sst_sec*1000+sst_cs*10) - ls_t[i])/10) - total_prev_k
            if syl_text == nil then
              syl_text = ""
            end
            k_lrc[i] = k_lrc[i]..string.format("{%s%d}%s",k_tag,kdur,syl_text)
            le_t[i] = sst_min*60*1000+sst_sec*1000+sst_cs*10
          end
          l.start_time = ls_t[i]
          l.end_time   = le_t[i]
          l.text       = k_lrc[i]
          subtitles.append(l)
          i=i+1
        else
          i=i+1
        end
      end
    end
    --for no k time lrc
    if lrc_with_k ~= true then
      line_n = 1
      full_text = {}
      --for omitted lrc
      for line in lyric:lines() do
        l_text,n = string.gsub(line,"%[%d+:%d+.%d+%]","")
        for st_min,st_sec,st_cs in string.gmatch(line,"%[(%d+):(%d+)%.(%d+)%]") do
          s_t_in_ms = st_min*60*1000+st_sec*1000+st_cs*10
          full_text[#full_text+1] = {start_time = s_t_in_ms,text = l_text}
        end
      end
      full_text[#full_text+1] = {start_time=3600000,text=""}
      table.sort(full_text,function(a,b) return a.start_time<b.start_time end )
      --append lines
      for j = 1,#full_text-1 do
        lst    = full_text[j]["start_time"]
        let    = full_text[j+1]["start_time"]
        l.text = full_text[j]["text"]
        aegisub.debug.out(lst)
        l.start_time = lst
        l.end_time = let
        subtitles.append(l)	
      end
    end
    lyric:close()
  else
  end
end

aegisub.register_macro(script_name, script_description, lyric_to_ass)
