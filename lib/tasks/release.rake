desc "Release a new project version"
task :release do
  require 'pathname'
  require 'yaml'
  require 'more_core_extensions/all'

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

  # Modify the automate domain version
  ae_file = root.join("db/fixtures/ae_datastore/ManageIQ/System/About.class/__class__.yaml")
  content = YAML.load_file(ae_file)
  content.store_path("object", "schema", 0, "field", "default_value", version)
  File.write(ae_file, content.to_yaml)

  # Create the commit and tag
  exit $?.exitstatus unless system("git add #{version_file} #{ae_file}")
  exit $?.exitstatus unless system("git commit -m 'Release #{version}'")
  exit $?.exitstatus unless system("git tag #{version}")

  puts
  puts "The commit on #{branch} with the tag #{version} has been created"
  puts "Run the following to push to the upstream remote:"
  puts
  puts "\tgit push upstream #{branch} #{version}"
  puts
end
