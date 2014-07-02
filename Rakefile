require 'rubygems'

require 'rake'
require 'rake/testtask'

Rake.application.options.trace = true

namespace :test do
  desc "Runs EVM vmdb specs"
  task :vmdb do
    ENV['RAILS_ENV'] = 'test'
    invoke_tasks(
      'test:load_vmdb_tasks',
      'evm:test:setup',
      'spec:evm:backend',
    )
  end

  desc "Run EVM migration specs"
  task :migrations do
    ENV['RAILS_ENV'] = 'test'
    invoke_tasks(
      'test:load_vmdb_tasks',
      'evm:test:setup_migrations',
      'spec:evm:migrations:up',
      'evm:test:complete_migrations:up',
      'spec:evm:migrations:down',
      'evm:test:complete_migrations:down'
    )
  end

  desc "Run EVM replication specs"
  task :replication do
    ENV['RAILS_ENV'] = 'test'
    invoke_tasks(
      'test:load_vmdb_tasks',
      'evm:test:setup_replication',
      'spec:evm:replication'
    )
  end

  desc "Run EVM automation specs"
  task :automation do
    ENV['RAILS_ENV'] = 'test'
    invoke_tasks(
      'test:load_vmdb_tasks',
      'evm:test:setup',
      'spec:evm:automation'
    )
  end

  desc "Run metric_fu metrics"
  task :run_metrics do
    ENV['RAILS_ENV'] = 'metric_fu'
    invoke_tasks(
      'test:load_vmdb_tasks',
      'evm:test:metrics'
    )
  end

  desc "Run brakeman static analysis"
  task :brakeman do
    ENV['RAILS_ENV'] = 'test'
    invoke_tasks(
      'test:load_vmdb_tasks',
      'brakeman:run'
    )
  end

  desc "Runs EVM lib tests in a single block"
  task :lib do
    invoke_tasks(
      'test:load_lib_tasks',
      :spec,
      :test
    )
  end

  task :load_vmdb_tasks do
    load_tasks('vmdb')
  end

  task :load_lib_tasks do
    load_tasks('lib')
  end

  task :upload_s3_bundle_cache do
    Dir.chdir(File.dirname(__FILE__))
    if upload_s3_bundle_cache? && File.exist?(bundle_cache_md5)
      puts "** Creating bundle cache file for upload"
      system("tar czf '#{bundle_cache_tgz}' -C '#{File.dirname(bundle_path)}' '#{File.basename(bundle_path)}'")
      puts "** Uploading bundle cache"
      system("ci/s3-put #{ENV['AMAZON_S3_BUCKET']}:#{tgz_file}")
      puts "** Uploading bundle cache MD5"
      system("ci/s3-put #{ENV['AMAZON_S3_BUCKET']}:#{md5_file}")
    end
  end

  def load_tasks(dir)
    update_bundle(dir)
    load_rakefile(dir)
  end

  def load_rakefile(dir)
    Dir.chdir(File.join(File.dirname(__FILE__), dir))
    $:.push(File.expand_path(File.join(__FILE__, dir)))
    load 'Rakefile'
  end

  def invoke_tasks(*tasks)
    tasks << 'test:upload_s3_bundle_cache' if upload_s3_bundle_cache?
    tasks.each { |t| Rake::Task[t].invoke }
  end

  def update_bundle(dir)
    Dir.chdir(File.join(File.dirname(__FILE__), dir))
    ENV['TRAVIS'] ? update_travis_bundle : update_other_ci_bundle
  end

  def update_travis_bundle
    FileUtils.mkdir_p bundle_path

    puts "** Fetching cached bundle"
    system("curl #{s3_url_tgz} | tar xz -C '#{File.dirname(bundle_path)}'")

    if upload_s3_bundle_cache?
      puts "** Fetching cached bundle MD5"
      old_md5 = `curl -s #{s3_url_md5} | cat`.chomp
    end

    puts "** Updating bundle"
    raise "Cannot update the bundle" unless system_retry('bundle update')

    if upload_s3_bundle_cache?
      puts "** Determining new cached bundle MD5"
      system("bundle clean --force")
      new_md5 = `md5deep -r #{bundle_path} | md5deep`.chomp
      File.write(bundle_cache_md5, new_md5) if old_md5 != new_md5
    end
  end

  def update_other_ci_bundle
    puts "** Checking bundle"
    if system('bundle check')
      puts "** Updating bundle"
      raise "Cannot update the bundle" unless system_retry('bundle update')
    end
  end

  def system_retry(cmd, count = 3)
    (1..count).each do |i|
      puts "** #{cmd} (try #{i}/#{count})"
      return true if system(cmd)
    end
    false
  end

  def bundle_path
    File.expand_path(ENV['BUNDLE_PATH'])
  end

  def tgz_file
    "#{ENV['BUNDLE_CACHE_FILE']}.tgz"
  end

  def md5_file
    "#{ENV['BUNDLE_CACHE_FILE']}.md5"
  end

  def s3_url_bucket
    File.join("https://s3.amazonaws.com", ENV['AMAZON_S3_BUCKET'])
  end

  def s3_url_tgz
    File.join(s3_url_bucket, tgz_file)
  end

  def s3_url_md5
    File.join(s3_url_bucket, md5_file)
  end

  def bundle_cache_tgz
    File.expand_path(File.join("~", tgz_file))
  end

  def bundle_cache_md5
    File.expand_path(File.join("~", md5_file))
  end

  def upload_s3_bundle_cache?
    # TODO: Change this to just ENV['TRAVIS_PULL_REQUEST'] == 'false'
    #       when ready for merge.
    ENV['TRAVIS_REPO_SLUG'].to_s.downcase == "manageiq/manageiq"
  end
end

namespace :build do
  desc "Upload the build files to an imagefactory instance"
  task :upload do
    raise "must set ENV['SCP_USER_HOST'], such as root@your_host" if ENV['SCP_USER_HOST'].nil?

    require 'pathname'
    build_dir = Pathname.new(File.join(File.dirname(__FILE__), 'build'))

    `ssh #{ENV['SCP_USER_HOST']} "rm -rf ~/manageiq && mkdir -p ~/manageiq"`
    `scp -qr #{build_dir} #{ENV['SCP_USER_HOST']}:~/manageiq/build`
  end

  namespace :shared_objects do
    desc "Clean built shared objects and artifacts."
    task :clean do
      require 'fileutils'
      require 'pathname'
      base = Pathname.new(File.dirname(__FILE__)).freeze

      artifacts_dirs = %w(
        lib/disk/modules/MiqBlockDevOps
        lib/disk/modules/MiqLargeFileLinux.d
        lib/SlpLib/SlpLib_raw/
        lib/NetappManageabilityAPI/NmaCore/NmaCore_raw
      )

      artifacts_dirs.each do |dir|
        dir = base.join(dir)
        patterns = %w(*.log *.o *.out Makefile)
        patterns.each do |p|
          Dir.glob(dir.join(p)) do |f|
            puts "** Removing #{f}"
            FileUtils.rm_f(f)
          end
        end
      end

      so_dirs = %w(
        lib/disk/modules/
        lib/SlpLib/lib/
        lib/NetappManageabilityAPI/NmaCore/
      )

      so_dirs.each do |dir|
        dir = base.join(dir)
        patterns = %w(**/*.so **/*.bundle)
        patterns.each do |p|
          Dir.glob(dir.join(p)) do |f|
            puts "** Removing #{f}"
            FileUtils.rm_f(f)
          end
        end
      end
    end
  end

  desc "Build shared objects"
  task :shared_objects do
    def build_shared_objects(so_name, make_dir, install_dir, extconf_params = nil)
      if File.exist?(install_dir.join(so_name))
        puts "** Skipping build of #{so_name} since it is already built."
        return
      end

      puts "** Building #{so_name}..."
      Dir.chdir(make_dir) do
        `ruby extconf.rb #{extconf_params}`
        `make`
        FileUtils.mkdir_p(install_dir)
        FileUtils.mv(so_name, install_dir)
      end
      puts "** Building #{so_name}...complete"
    end

    require 'fileutils'
    require 'pathname'

    base      = Pathname.new(File.dirname(__FILE__)).freeze
    platform  = RUBY_PLATFORM.match(/(.+?)[0-9\.]*$/)[1] # => "x86_64-linux" or "x86_64-darwin"
    _arch, os = platform.split("-")                      # => ["x86_64", "linux"]

    #
    # MiqBlockDevOps
    #

    if platform == "x86_64-linux"
      build_shared_objects(
        "MiqBlockDevOps.so",
        base.join("lib/disk/modules/MiqBlockDevOps/"),
        base.join("lib/disk/modules/")
      )
    else
      puts "** Skipping build of MiqBlockDevOps.so since it is only built on x86_64-linux."
    end

    #
    # MiqLargeFileLinux
    #

    if platform == "x86_64-linux"
      build_shared_objects(
        "MiqLargeFileLinux.so",
        base.join("lib/disk/modules/MiqLargeFileLinux.d/"),
        base.join("lib/disk/modules/ruby#{RUBY_VERSION}/")
      )
    else
      puts "** Skipping build of MiqLargeFileLinux.so since it is only built on x86-linux."
    end

    #
    # SlpLib
    #

    if os == "darwin"
      include_file = "/usr/local/include/slp.h"
      lib_file     = "/usr/local/lib/libslp.dylib"
      so_name      = "SlpLib_raw.bundle"
    else # RHEL, Fedora
      include_file = "/usr/include/slp.h"
      lib_file     = "/usr/lib64/libslp.so"
      so_name      = "SlpLib_raw.so"
    end

    if File.exist?(include_file) && File.exist?(lib_file)
      build_shared_objects(
        so_name,
        base.join("lib/SlpLib/SlpLib_raw/"),
        base.join("lib/SlpLib/lib/#{platform}/")
      )
    else
      puts "** Skipping build of #{so_name} due to missing header or library."
    end

    #
    # NmaCore
    #

    if Dir.exist?("/usr/include/netapp") && Dir.exist?("/usr/lib64/netapp")
      build_shared_objects(
        "NmaCore_raw.so",
        base.join("lib/NetappManageabilityAPI/NmaCore/NmaCore_raw/"),
        base.join("lib/NetappManageabilityAPI/NmaCore/#{platform}/ruby#{RUBY_VERSION}/")
      )
    else
      puts "** Skipping build of NmaCore_raw.so due to missing header or library."
    end
  end
end
