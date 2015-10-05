require 'sys-uname'
require "open3"

class MiqSyntaxChecker
  def self.check(ruby)
    return MiqSyntaxCheckResult.new("Syntax OK\n") if Sys::Platform::OS == :windows

    Open3.popen3 "ruby -wc" do |stdin, stdout, stderr|
      stdin.write ruby
      stdin.close
      output = stdout.read
      errors = stderr.read
      MiqSyntaxCheckResult.new(output && !output.empty? ? output : errors)
    end
  end
end

class MiqSyntaxCheckResult
  def initialize(output)
    @valid = (output == "Syntax OK\n")
    @output = output
    unless @valid
      match = /^-:(\d+):(.*)/.match(output)
      if match.nil?
        @error_line = 0
        @error_text = output
      else
        @error_line = match[1].to_i
        @error_text = match[2]
      end
    end
  end

  attr_reader :error_line

  attr_reader :error_text

  def valid?
    @valid
  end
end
