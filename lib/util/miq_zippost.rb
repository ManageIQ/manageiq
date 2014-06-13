#!/usr/bin/env ruby 

require 'rubygems' 
require 'zip/zipfilesystem' 
require 'net/http'
require 'optparse'
require 'digest/md5' 

require 'miq-xml'

class MiqZipPost
  def initialize(url, dir, zipfile)
    @url = url
    @dir = dir
    @zfile = zipfile
    @data = nil
  end

  def zipdir
    raise "directory #{@dir} does not exist" unless File.exists?(@dir)
    
    File.delete(@zfile) if File.exist?(@zfile)
    Zip::ZipFile.open(@zfile, Zip::ZipFile::CREATE) do |zip|
      Dir.glob(@dir + "/*").each {|file|
        next if File.directory?(file)

        path = File.basename(file)
        puts "Adding: #{path}"
        zip.file.open(path, 'w') { |f1| f1 << File.read(file) } 
      }
      zip.close
    end
  end

  def post
    zipdir
    
    data = nil; File.open(@zfile, "rb") {|f| data = f.read; f.close}
    query = {"filename" => File.basename(@zfile),
             "md5" => Digest::MD5.hexdigest(data).to_s,
             "data" => MIQEncode.encode(data),
             }
    puts "Sending: #{@zfile} to #{@url}"
    begin
      res = Net::HTTP.post_form(URI.parse(@url), query)
      puts res.body
    rescue => err
      puts "error opening #{@url}, #{err}"
      exit 1
    end

    if ["200", "201"].include?(res.code)
      puts "Request successful: Code: #{res.code}, Message: #{res.msg}"
    else
      puts "Request failed: Code: #{res.code}, Message: #{res.msg}"
    end
    
    @data = res.body
  end

  def data
    @data
  end
end #class MiqZipPost

if __FILE__ == $0

url, dir, zfile = nil
opts = OptionParser.new
opts.on('--url=<url>', 'Destination URL', String) {|val| url = val}
opts.on('--dir=<dir>', 'Source directory', String) {|val| dir = val}
opts.on('--zipfile=<filename>', 'Path of zip file', String) {|val| zfile = val}
opts.parse(*ARGV) unless ARGV.empty?

#zfile = File.join(File.dirname(dir), "miqpost.zip")
data = MiqZipPost.new(url, dir, zfile).post

doc = MiqXml.load(data)

xmlfile = "./packages.xml"
fd = File.open(xmlfile, "w")
doc.write(STDOUT, 0)
doc.write(fd, 0)
fd.close

puts "\ndone"
end
