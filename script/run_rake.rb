$:.unshift(File.dirname(__FILE__))
require 'miq_std_io'

task = ARGV[0]

# When Raking, some output and errors are printed from the lower levels which are meaningless for us to log or display in the UI.
# By running rake through the .invoke method, we can capture the output we want and catch the exact Exception that is raised on error.
# Require rake and the classes needed to run rake db:migrate through Rake::Task['db:migrate'].invoke.
require 'rake'
load './Rakefile'

MiqStdIo.std_io_to_files do
  begin
    Rake::Task[task].invoke
  rescue Exception => err
    # Rake db tasks write to $stderr, rewind so we can write our own custom message
    $stderr.rewind
    $stderr.write("'#{task}' failed due to error: #{err}", true)
    exit 1
  end
  $stdout.write("'#{task}' successful\n")
  exit 0
end

