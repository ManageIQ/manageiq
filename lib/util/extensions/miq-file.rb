require 'rubygems'
require 'platform'
require 'uri'
require 'win32/file' if Platform::OS == :win32
require_relative '../../disk/modules/MiqLargeFile'
require_relative '../runcmd'
require_relative '../MiqSockUtil'

class File
  def self.paths_equal?(f1, f2)
    if Platform::OS == :win32
      f1 = File.short_path(f1).downcase
      f2 = File.short_path(f2).downcase
    end

    File.normalize(f1) == File.normalize(f2)
  end

  def self.normalize(path)
    File.expand_path(path.tr("\\", "/"))
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
