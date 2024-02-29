require 'miq-process'

class PidFile
  def initialize(fname)
    @fname = fname
  end

  def self.create(fname, remove_on_exit = true)
    new(fname).create(remove_on_exit)
  end

  def self.remove(fname)
    new(fname).remove
  end

  def pid
    return nil unless File.file?(@fname)

    data = File.read(@fname).strip
    return nil if data.empty? || !/\d+/.match(data)

    data.to_i
  end

  def remove
    FileUtils.rm(@fname) if pid == Process.pid
  end

  def create(remove_on_exit = true)
    FileUtils.mkdir_p(File.dirname(@fname))
    File.write(@fname, Process.pid)
    at_exit { PidFile.remove(@fname) } if remove_on_exit
  end

  def running?(regexp = nil)
    pid = self.pid
    return false if pid.nil?

    command_line = MiqProcess.command_line(pid)
    return false if command_line.blank?

    unless regexp.nil?
      regexp = Regexp.new(regexp) if regexp.kind_of?(String)
      return false if regexp.match(command_line).nil?
    end

    true
  end
end
