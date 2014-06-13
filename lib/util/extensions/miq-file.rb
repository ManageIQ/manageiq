$:.push("#{File.dirname(__FILE__)}/../../disk/modules")
$:.push("#{File.dirname(__FILE__)}/..")

require 'rubygems'
require 'platform'
require "Win32API" if Platform::OS == :win32
require 'MiqLargeFile'
require 'runcmd'
require 'uri'
require 'MiqSockUtil'

class File
  def self.paths_equal?(f1, f2)
    if Platform::OS == :win32
      # Note: The file needs to exist and be accessable for getShortFileName to work.
      f1 = File.getShortFileName(f1).downcase
      f2 = File.getShortFileName(f2).downcase
    end

    File.expand_path(f1).gsub("\\","/") == File.expand_path(f2).gsub("\\","/")
  end

  def self.getShortFileName(longName)
    if Platform::OS == :win32
      size = 255
      buffer = " " * 255
      returnSize = Win32API.new("kernel32" , "GetShortPathNameA" , 'ppl'  , 'L').Call(longName ,  buffer , size )
      a = ""
      a = a + buffer[0...returnSize]        
      return a
    else
      return longName
    end
  end
  
  def self.normalize(path)
    File.expand_path(path.gsub(/\\/,"/"))
  end
  
  def self.splitpath(path)
    ext = File.extname(path)
    return File.dirname(path), File.basename(path, ext), ext
  end

  # Extended File.size method to handle files over 2GB
  def self.sizeEx(path)
    case Platform::IMPL
    when :linux
      MiqUtil.runcmd("ls -lQ \"#{path}\"").split(" ")[4].to_i
    when :mswin, :mingw
      MiqLargeFile.size(path)
    else
      File.size(path)
    end
  end

  def self.path_to_uri(file, hostname=nil)
    hostname ||= MiqSockUtil.getFullyQualifiedDomainName
    URI::join("file://#{hostname}", "/#{URI.encode(file.gsub('\\','/'))}").to_s
  end

  def self.uri_to_local_path(uri_path)
    begin
      # Detect and return UNC paths
      return URI.decode(uri_path) if uri_path[0,2] == '//'
      local = URI.decode(URI.parse(uri_path).path)
      return local[1..-1] if local[2,1] == ':'
      return local
    rescue
      return uri_path
    end
  end
end
