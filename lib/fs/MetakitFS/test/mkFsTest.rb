
$:.push("#{File.dirname(__FILE__)}/..")
$:.push("#{File.dirname(__FILE__)}/../../MiqFS")

require 'ostruct'
require 'find'
require 'fileutils'

require 'MiqFS'
require 'MetakitFS'

# MK_FILE = "mk4test"
MK_FILE = "newmkfs"
FROM_DIR = "../.."
SAMP_FILE = "/lib/fs/MetakitFS/MetakitFS.rb"

def copyIn(fs, ff, tf)
    File.open(ff) do |ffo|
        tfo = fs.fileOpen(tf, "wb")
        while (buf = ffo.read(1024))
            tfo.write(buf, buf.length)
        end
        tfo.close
    end
end

begin
    # begin
    #     File.delete(MK_FILE)
    # rescue
    # end
    # FileUtils.cp("hello", MK_FILE)
    
    dobj = OpenStruct.new
    dobj.mkfile = MK_FILE
    dobj.create = true

	if !MetakitFS.supported?(dobj)
		puts "#{MK_FILE} is not a mkfs"
		exit
	end
     
    mkFS = MiqFS.new(MetakitFS, dobj)
    
    # Dir.chdir FROM_DIR
    # Find.find(".") do |path|
    #     if File.directory? path
    #         Find.prune if File.basename(path) == ".svn"
    #         puts "Creating directory: #{path}"
    #         mkFS.dirMkdir(path)
    #     else
    #         next if File.basename(path) == MK_FILE
    #         puts "Copying file: #{path}"
    #         copyIn(mkFS, path, path)
    #     end
    # end
    
    puts
    puts "*****************************"
    puts

	# puts "fsId = #{mkFS.fsId}"
	# puts "Tags for /:"
	# mkFS.tags("/").each { |t| puts "\t#{t}" }
	# puts
    
    mkFS.findEach("/") do |path|
        puts "\t#{path}"
        mkFS.fileOpen(path) do |fo|
            # tags = fo.tags
            # if !tags.empty?
            #     puts "\tTAGS:"
            #     tags.each { |t| puts "\t\t#{t}" }
            #     puts
            # end
        end
    end

	if !mkFS.hasTagName?("/", "LABEL")
		puts "*** Adding label..."
		mkFS.tagAdd("/", "LABEL=MIQPAYLOAD")
	end

	exit
    
    puts
    puts "*****************************"
    puts
    
    fo = mkFS.fileOpen(SAMP_FILE)
    fo.addTag("Rich")
    fo.addTag("was")
    fo.addTag("here")
    fo.close
    
    puts "FILE: #{SAMP_FILE}"
    mkFS.fileOpen(SAMP_FILE) do |fo|
        puts "\tTAGS:"
        fo.tags.each { |t| puts "\t\t#{t}"}
        puts
        puts "***** CONTENTS:"
        unzipper = Zlib::Inflate.new 
        while (buf = fo.read(1024)).length != 0
            unzipper << buf
        end
        puts unzipper.inflate(nil)
    end
    
    fo = mkFS.fileOpen(SAMP_FILE)
    fo.deleteTag("was")
    puts "\tTAGS:"
    fo.tags.each { |t| puts "\t\t#{t}"}
    fo.close
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
end