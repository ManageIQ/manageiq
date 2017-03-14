desc "Release a new project version"
task :release do
  require 'pathname'

  version = ENV["RELEASE_VERSION"]
  if version.nil? || version.empty?
    STDERR.puts "ERROR: You must set the env var RELEASE_VERSION to the proper value."
    exit 1
  end

  branch = `git rev-parse --abbrev-ref HEAD`.chomp
  if branch == "master"
    STDERR.puts "ERROR: You cannot cut a release from the master branch."
    exit 1
  end

  root = Pathname.new(__dir__).join("../..")

  # Modify the VERSION file
  version_file = root.join("VERSION")
  File.write(version_file, version)

  # Create the commit and tag
  exit $?.exitstatus unless system("git add #{version_file}")
  exit $?.exitstatus unless system("git commit -m 'Release #{version}'")
  exit $?.exitstatus unless system("git tag #{version}")

  puts
  puts "The commit on #{branch} with the tag #{version} has been created"
  puts "Run the following to push to the upstream remote:"
  puts
  puts "\tgit push upstream #{branch} #{version}"
  puts
end
