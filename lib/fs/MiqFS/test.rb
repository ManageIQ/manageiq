require 'MiqFS'

Dir.chdir(File.dirname(__FILE__))

mfs = MiqFS.getFS("test_disk")

puts "FS type: #{mfs.fsType}"
puts "pwd = #{mfs.pwd}"

mfs.chdir(Dir.pwd)
puts "pwd = #{mfs.pwd}"

puts "Files:"
mfs.dirForeach(".") { |f| puts "\t#{f}" }

puts "Files in modules:"
mfs.dirForeach("modules") { |f| puts "\t#{f}" }

puts "Files in modules (*.rb):"
mfs.dirGlob("*.rb") { |f| puts "\t#{f}" }

puts "now the array:"
p mfs.dirGlob("*.rb")

puts "File attributes:"
mfs.dirGlob("*.rb") do |f|
    puts "\tFile: #{f}"
    puts "\t    By name:"
    puts "\t\tExists:\t#{mfs.fileExists?(f)}"
    puts "\t\tDir:\t#{mfs.fileDirectory?(f)}"
    puts "\t\tFile:\t#{mfs.fileFile?(f)}"
    puts "\t\tSize:\t#{mfs.fileSize(f)}"
    puts "\t\tAtime:\t#{mfs.fileAtime(f)}"
    puts "\t\tCtime:\t#{mfs.fileCtime(f)}"
    puts "\t\tMtime:\t#{mfs.fileMtime(f)}"
    
    puts "\t    By object:"
    mfs.fileOpen(f) do |fo|
      puts "\t\tAtime:\t#{fo.atime}"
      puts "\t\tCtime:\t#{fo.ctime}"
      puts "\t\tMtime:\t#{fo.mtime}"
    end
end

puts "\nWithout block"
mfs.dirGlob("*.rb") do |f|
	puts "#{f} contents:"
	fo = mfs.fileOpen(f)
	fo.each { |l| puts "\t#{l}" }
	fo.close
end

puts "\nWith block"
mfs.dirGlob("*.rb") do |f|
	puts "#{f} contents:"
	mfs.fileOpen(f) do |fo|
		fo.each { |l| puts "\t#{l}" }
	end
end
