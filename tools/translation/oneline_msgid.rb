#
# Samples
#
# Input is one-liner to begin with
# msgid=["msgid \"Hello World\"\n"]
#
# Input is multi-line
# msgid=["msgid \"\"\n", "\"Drag items here to add to the dialog. At least one item is required before sav\"\n", "\"ing\"\n"]
#
def msgid_array_to_one_liner(msgid)
  return msgid.first if msgid.length == 1

  one_liner = ""
  msgid.each do |string|
    string = string[1,string.length-1] if string.start_with?("\"")
    string = string[0,string.length-2] if string.end_with?("\"\n")
    one_liner += string
  end
  one_liner += "\"\n"
end

def process_file(fname)
  File.open("#{fname}.oneline_msgid", "w") do |ofile|
    msgid = nil
    File.foreach(fname) do |line|
      if line.start_with?("msgid ")
        msgid = [ line ]
      elsif msgid.kind_of?(Array)
        if line.start_with?("\"")
          msgid << line
        else
          ofile.puts(msgid_array_to_one_liner(msgid))
          ofile.puts(line)
          msgid = nil
        end
      else
        ofile.puts(line)
      end
    end
  end
end

for fname in ARGV
  if File.file?(fname)
    STDERR.puts("Processing Source File <#{fname}> ...")
    process_file(fname)
    STDERR.puts("Processing Source File <#{fname}> complete")
  else
    STDERR.puts("Source File <#{fname}> does not exist")
  end
end
