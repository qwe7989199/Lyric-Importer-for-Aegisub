--[[ This script is used to convert the special format lyric file of Kugou Music (.krc) , QQ Music (.qrc) and LyRiCs (.lrc) into ASS format.
  You could get these lyric files from the software above or foobar2000 with "ESLyric" plugin.
--]]

local tr = aegisub.gettext
script_name = tr"Import Lyric File"
script_description = tr"Import Lyric File For Aegisub"
script_author = "domo&SuJiKiNen"
script_version = "1.2"

k_tag="\\K"  --you can change this to \\k or \\kf
NOT_SET_ENDTIME = -1

local ffi = require('ffi')
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
  line.actor,line.effect,line.text  = " "," "," "
  line.extra = {}
  return line
end

function ass_simple_line(st,et,text)
  line = ass_line_template()
  line.start_time = st
  line.end_time   = et
  line.text       = text
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
  for krc_line in string.gmatch(decoded_str,"%[%d+,%d+%][^%[]*") do
    ass_line = krc_parse_line(krc_line)
    table.insert(convert_subtitles,ass_line)
  end
  return convert_subtitles
end

function krc_parse_line(krc_line)
  lst,ldur,syls_str = string.match(krc_line,"^%[(%d+),(%d+)%](.*)$")
  let = lst + ldur
  ltext = ""
  for t3,t4,syl_text in string.gmatch(syls_str,"<(%d+),(%d+),%d+>([^<]+)") do
    kdur     = round(t4/10)
    syl_text = string.gsub(syl_text,"　",string.format("{%s%d}　[^\n]",k_tag,"0"))
    syl_text = string.gsub(syl_text,"[　 ]*[\n\r]+","")
    ltext    = ltext..string.format("{%s%d}",k_tag,kdur)..syl_text
  end
  return ass_simple_line(lst,let,ltext)
end

function qrc_handler(encoded_str)
  local convert_subtitles = {}
  local encoded_c_str = ffi.new("char[?]", (#encoded_str)+1)
  ffi.copy(encoded_c_str, encoded_str)
  decoded_p = lyric_decoder.qrcdecode(encoded_c_str,#encoded_str)
  decoded_str = ""
  if decoded_p then
    decoded_str = ffi.string(decoded_p)
    ffi.C.free(decoded_p)
  end

  for qrc_line in string.gmatch(decoded_str,"%[%d+,%d+%][^%[]*") do
    ass_line = qrc_parse_line(qrc_line)
    table.insert( convert_subtitles,ass_line )
  end
  return convert_subtitles
end

function qrc_parse_line(qrc_line)
  lst,ldur,syls_str = string.match(qrc_line,"%[(%d+),(%d+)%](.*)")
  let  = lst + ldur
  ltext = ""
  for syl_text,t3,t4 in string.gmatch(syls_str,"([^%(]*)%((%d+),(%d+)%)") do
    kdur     = round(t4/10)
    syl_text = string.gsub(syl_text,"　",string.format("{%s%d}　",k_tag,"0"))
    syl_text = string.gsub(syl_text,"[　 ]*[\n\r]+","")
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
  else -- normal line or merged timed time
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
