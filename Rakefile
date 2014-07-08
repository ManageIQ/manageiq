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

  def load_tasks(dir)
    update_bundle(dir)
    load_rakefile(dir)
  end

  def load_rakefile(dir)
    Dir.chdir(File.join(File.dirname(__FILE__), dir))
    $:.push(File.expand_path(File.join(__FILE__, dir)))
    load 'Rakefile'
  end

  def update_bundle(dir)
    Dir.chdir(File.join(File.dirname(__FILE__), dir))
    unless system('bundle check')
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

  def invoke_tasks(*tasks)
    tasks.each { |t| Rake::Task[t].invoke }
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
