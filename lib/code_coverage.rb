require 'pathname'
module CodeCoverage
  # The HOOK_FILE is responsible for starting or restarting code coverage.
  # Child worker forks inherit the code coverage environment when the server
  # invoked the 'run_hook' so they must reset the environment for the new process.
  HOOK_FILE = Pathname.new(__dir__).join("..", "config", "coverage_hook.rb").freeze
  def self.run_hook
    # Note: We use 'load' here because require would only load the hook once,
    # in the server but not when the child fork starts.  Shared memory is hard.
    load HOOK_FILE if File.exist?(HOOK_FILE)
  end
end
