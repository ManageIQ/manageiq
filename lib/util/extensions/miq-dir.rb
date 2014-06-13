require 'fileutils'

class Dir
  def self.mkpath(path, *args)
    FileUtils.mkdir_p(path, *args)
  end
end
