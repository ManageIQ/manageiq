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

    FileUtils.ln_s(lock_release, gemfile_lock, :force => true)

    exit $?.exitstatus unless Bundler.unbundled_system({"BUNDLE_IGNORE_CONFIG" => "true", "APPLIANCE" => "true"}, "bundle lock --update --conservative --patch")

    FileUtils.rm(gemfile_lock)

    lock_content = lock_release.read
    lock_release.write(lock_content.gsub("branch: #{branch}", "tag: #{version}"))
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
  exit $?.exitstatus unless system("git tag #{version} -m 'Release #{version}'")

  # Revert the Gemfile and Gemfile.lock update
  gemfile.write(content)
  lock_release.write(lock_content) if lock_release.exist?

  # Commit
  files_to_update = [gemfile]
  files_to_update << lock_release if lock_release.exist?
  exit $?.exitstatus unless system("git add #{files_to_update.join(" ")}")
  exit $?.exitstatus unless system("git commit -m 'Revert Gemfile tag reference update and put back branch reference'")

  puts
  puts "The commit on #{branch} with the tag #{version} has been created."
  puts "Run the following to push to the upstream remote:"
  puts
  puts "\tgit push upstream #{branch} #{version}"
  puts
end

namespace :release do
  desc "Tasks to run on a new branch when a new branch is created"
  task :new_branch do
    require 'pathname'

    branch = ENV["RELEASE_BRANCH"]
    if branch.nil? || branch.empty?
      STDERR.puts "ERROR: You must set the env var RELEASE_BRANCH to the proper value."
      exit 1
    end

    next_branch = ENV["RELEASE_BRANCH_NEXT"]
    if next_branch.nil? || next_branch.empty?
      STDERR.puts "ERROR: You must set the env var RELEASE_BRANCH_NEXT to the proper value."
      exit 1
    end

    current_branch = `git rev-parse --abbrev-ref HEAD`.chomp
    if current_branch == "master"
      STDERR.puts "ERROR: You cannot do new branch tasks from the master branch."
      exit 1
    end

    root = Pathname.new(__dir__).join("../..")

    # Modify Gemfile
    gemfile = root.join("Gemfile")
    content = gemfile.read
    gemfile.write(content.gsub(/(:branch => ")[^"]+(")/, "\\1#{branch}\\2"))

    # Modify Dockerfile
    dockerfile = root.join("Dockerfile")
    content = dockerfile.read
    dockerfile.write(content.sub(/^(ARG IMAGE_REF=).+/, "\\1latest-#{branch}"))

    # Modify VERSION
    version_file = root.join("VERSION")
    version_file.write("#{branch}-pre")

    # Modify CODENAME
    vmdb_appliance = root.join("lib", "vmdb", "appliance.rb")
    content = vmdb_appliance.read
    vmdb_appliance.write(content.sub(/(CODENAME\n\s+")[^"]+(")/, "\\1#{branch.capitalize}\\2"))

    # Modify Deprecation version
    deprecation = root.join("lib", "vmdb", "deprecation.rb")
    content = deprecation.read
    deprecation.write(content.sub(/(ActiveSupport::Deprecation.new\(")[^"]+(")/, "\\1#{next_branch.capitalize}\\2"))

    # Commit
    files_to_update = [gemfile, dockerfile, version_file, vmdb_appliance, deprecation]
    exit $?.exitstatus unless system("git add #{files_to_update.join(" ")}")
    exit $?.exitstatus unless system("git commit -m 'Changes for new branch #{branch}'")

    puts
    puts "The commit on #{current_branch} has been created."
    puts "Run the following to push to the upstream remote:"
    puts
    puts "\tgit push upstream #{current_branch}"
    puts
  end

  desc "Tasks to run on the master branch when a new branch is created"
  task :new_branch_master do
    require 'pathname'

    branch = ENV["RELEASE_BRANCH"]
    if branch.nil? || branch.empty?
      STDERR.puts "ERROR: You must set the env var RELEASE_BRANCH to the proper value."
      exit 1
    end

    next_branch = ENV["RELEASE_BRANCH_NEXT"]
    if next_branch.nil? || next_branch.empty?
      STDERR.puts "ERROR: You must set the env var RELEASE_BRANCH_NEXT to the proper value."
      exit 1
    end

    current_branch = `git rev-parse --abbrev-ref HEAD`.chomp
    if current_branch != "master"
      STDERR.puts "ERROR: You cannot do master branch tasks from a non-master branch (#{current_branch})."
      exit 1
    end

    root = Pathname.new(__dir__).join("../..")

    # Modify CODENAME
    vmdb_appliance = root.join("lib", "vmdb", "appliance.rb")
    content = vmdb_appliance.read
    vmdb_appliance.write(content.sub(/(CODENAME\n\s+")[^"]+(")/, "\\1#{next_branch.capitalize}\\2"))

    # Modify Deprecation version
    deprecation = root.join("lib", "vmdb", "deprecation.rb")
    content = deprecation.read
    deprecation.write(content.sub(/(ActiveSupport::Deprecation.new\(")[^"]+(")/, "\\1#{next_branch[0].capitalize.next}-release\\2"))

    # Commit
    files_to_update = [vmdb_appliance, deprecation]
    exit $?.exitstatus unless system("git add #{files_to_update.join(" ")}")
    exit $?.exitstatus unless system("git commit -m 'Changes after new branch #{branch}'")

    puts
    puts "The commit on #{current_branch} has been created."
    puts "Run the following to push to the upstream remote:"
    puts
    puts "\tgit push upstream #{current_branch}"
    puts
  end

  desc "Generate the Gemfile.lock.release file"
  task :generate_lockfile do
    branch = ENV["RELEASE_BRANCH"]
    if branch.nil? || branch.empty?
      STDERR.puts "ERROR: You must set the env var RELEASE_BRANCH to the proper value."
      exit 1
    end

    update_gems = ENV["UPDATE_GEMS"].to_s.split(" ")

    root = Pathname.new(__dir__).join("../..")

    # Ensure that local and global bundler.d is not enabled
    local_bundler_d  = root.join("bundler.d")
    global_bundler_d = Pathname.new(Dir.home).join(".bundler.d")
    if (local_bundler_d.exist? && local_bundler_d.glob("*.rb").any?) ||
       (global_bundler_d.exist? && global_bundler_d.glob("*.rb").any?)
      STDERR.puts "ERROR: You cannot run generate_lockfile with bundler-inject files present."
      exit 1
    end

    begin
      if root.join("Gemfile.lock.release").exist?
        FileUtils.cp(root.join("Gemfile.lock.release"), root.join("Gemfile.lock"))
      else
        # First time build of Gemfile.lock.release
        update_gems = ["*"]
        root.join("Gemfile.lock").delete
      end

      if update_gems.any?
        cmd =
          if update_gems == ["*"]
            "bundle update" # Update everything regardless of patch level
          else
            "bundle update --conservative --patch #{update_gems.join(" ")}"
          end

        Bundler.with_unbundled_env do
          puts "** Updating gems #{update_gems.join(", ")}"
          exit $?.exitstatus unless system({"APPLIANCE" => "true"}, cmd, :chdir => root)
        end
      end

      platforms = %w[
        arm64-darwin
        ruby
        x86_64-linux
        x86_64-darwin
        powerpc64le-linux
      ].sort_by { |p| [RUBY_PLATFORM.start_with?(p) ? 0 : 1, p] }

      Bundler.with_unbundled_env do
        platforms.each do |p|
          puts "** #{p}"
          exit $?.exitstatus unless system({"APPLIANCE" => "true"}, "bundle lock --conservative --add-platform #{p}", :chdir => root)
        end
      end

      FileUtils.cp(root.join("Gemfile.lock"), root.join("Gemfile.lock.release"))
    end
  end
end
