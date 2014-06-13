$:.push("#{File.dirname(__FILE__)}")
require 'peheader'

class File
  def File.getVersionInfo(fname)
    PEheader.new(fname).versioninfo
  end
end

 ###########################################################
# Only run if we are calling this script directly
if __FILE__ == $0 then
  puts "Running script [#{__FILE__}]"
  vi = File.getVersionInfo("c:/temp/strings.exe")
  #vi = File.getVersionInfo("c:/windows/system32/mui/0419/xpob2res.dll")  #Russian version_info file
  vi.each_pair {|k,v| puts "vi[#{k}] = [#{v}]"}
  puts "Completed script [#{__FILE__}]"
end
