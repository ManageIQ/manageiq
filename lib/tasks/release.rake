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

  # Update Gemfile.lock if exist
  lock_release = root.join("Gemfile.lock.release")
  if lock_release.exist?
    gemfile_lock = lock_release.to_s.chomp(".release")
    appliance_dependency = root.join("bundler.d/manageiq-appliance-dependencies.rb")

    FileUtils.ln_s(lock_release, gemfile_lock, :force => true)
    FileUtils.ln_s(root.join("../manageiq-appliance/manageiq-appliance-dependencies.rb"),
                   appliance_dependency, :force => true)

    exit $?.exitstatus unless Bundler.unbundled_system({"BUNDLE_IGNORE_CONFIG" => "true", "APPLIANCE" => "true"}, "bundle lock --update --conservative --patch")

    FileUtils.rm([appliance_dependency, gemfile_lock])

    content = lock_release.read
    lock_release.write(content.gsub("branch: #{branch}", "tag: #{version}"))
  end

  # Change git based gem source to tag reference in Gemfile
  gemfile = root.join("Gemfile")
  content = gemfile.read
  gemfile.write(content.gsub(":branch => \"#{branch}\"", ":tag => \"#{version}\""))

  # Commit
  files_to_update = [version_file, gemfile]
  files_to_update << lock_release if lock_release.exist?
  exit $?.exitstatus unless system("git add #{files_to_update.join(" ")}")
  exit $?.exitstatus unless system("git commit -m 'Release #{version}'")

  # Tag
  exit $?.exitstatus unless system("git tag #{version}")

  # Revert the Gemfile update
  gemfile.write(content)
  exit $?.exitstatus unless system("git add #{gemfile}")
  exit $?.exitstatus unless system("git commit -m 'Revert Gemfile tag reference update and put back branch reference'")

  puts
  puts "The commit on #{branch} with the tag #{version} has been created"
  puts "Run the following to push to the upstream remote:"
  puts
  puts "\tgit push upstream #{branch} #{version}"
  puts
end
