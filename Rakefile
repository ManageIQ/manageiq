require 'rubygems'

require 'rake'
require 'rake/testtask'

Rake.application.options.trace = true

namespace :test do
  desc "Runs EVM vmdb specs"
  task :vmdb do
    ENV['RAILS_ENV'] = 'test'
    ['test:load_vmdb_tasks', 'evm:test:setup', 'spec:evm:backend'].each { |t| Rake::Task[t].invoke }
  end

  desc "Run EVM migration specs"
  task :migrations do
    ENV['RAILS_ENV'] = 'test'
    ['test:load_vmdb_tasks', 'evm:test:setup_migrations', 'spec:evm:migrations:up', 'evm:test:complete_migrations:up', 'spec:evm:migrations:down', 'evm:test:complete_migrations:down'].each { |t| Rake::Task[t].invoke }
  end

  desc "Run EVM replication specs"
  task :replication do
    ENV['RAILS_ENV'] = 'test'
    ['test:load_vmdb_tasks', 'evm:test:setup_replication', 'spec:evm:replication'].each { |t| Rake::Task[t].invoke }
  end

  desc "Run EVM automation specs"
  task :automation do
    ENV['RAILS_ENV'] = 'test'
    ['test:load_vmdb_tasks', 'evm:test:setup', 'spec:evm:automation'].each { |t| Rake::Task[t].invoke }
  end

  desc "Run metric_fu metrics"
  task :run_metrics do
    ENV['RAILS_ENV'] = 'metric_fu'
    ['test:load_vmdb_tasks', 'evm:test:metrics'].each { |t| Rake::Task[t].invoke }
  end

  desc "Run brakeman static analysis"
  task :brakeman do
    ENV['RAILS_ENV'] = 'test'
    ['test:load_vmdb_tasks', 'brakeman:run'].each { |t| Rake::Task[t].invoke }
  end

  desc "Runs EVM lib tests in a single block"
  task :lib do
    ['test:load_lib_tasks', :spec, :test].each { |t| Rake::Task[t].invoke }
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
        lib/VixDiskLib/VixDiskLib_raw/v1_2/
        lib/VixDiskLib/VixDiskLib_raw/v5_0/
        lib/VixDiskLib/VixDiskLib_raw/v5_1/
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
        lib/VixDiskLib/lib/
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

    #
    # VixDiskLib
    #

    { # VDL version => library version
      "5.1" => "5.1.0",
      "5.0" => "5.0.0",
      "1.2" => "1.1.2"
    }.each do |vdl_version, lib_version|
      vdl_version_underscore = vdl_version.gsub(".", "_")

      include_dir = Pathname.new(ENV["VDL_#{vdl_version_underscore}_INCLUDE"] || "/usr/lib/vmware-vix-disklib/include")
      lib_dir     = Pathname.new(ENV["VDL_#{vdl_version_underscore}_LIB"]     || "/usr/lib/vmware-vix-disklib/lib64")
      so_name     = "VixDiskLib_raw.#{vdl_version}.so"
      if Dir.exist?(include_dir) && Dir.exist?(lib_dir) && File.exist?(lib_dir.join("libvixDiskLib.so.#{lib_version}"))
        build_shared_objects(
          so_name,
          base.join("lib/VixDiskLib/VixDiskLib_raw/v#{vdl_version_underscore}/"),
          base.join("lib/VixDiskLib/lib/#{platform}/ruby#{RUBY_VERSION}/"),
          "--with-vixDiskLib-include #{include_dir} --with-vixDiskLib-lib #{lib_dir}"
        )
      else
        puts "** Skipping build of #{so_name} due to missing header or library."
      end
    end
  end

  namespace :image do

    KICKSTARTS = "git://git.app.eng.bos.redhat.com/cfme_productization.git?manageiq/build/productization/kickstarts#"

    def brew_cmd(config_file, kickstart_file)
      brew_cmd_string = "brew image-build --nowait --config #{config_file} --repo #{ENV['PUDDLE']} "
      brew_cmd_string << "--repo http://download.eng.bos.redhat.com/devel/cfme/repos/rhel-6.5.z-x86_64-latest-pkgs "
      brew_cmd_string << "--kickstart #{kickstart_file} "
      brew_cmd_string << "--ksurl #{KICKSTARTS}#{KICKSTART_SHA}"
      brew_cmd_string
    end

    task :kerberos_init do
      system('kinit') unless system('klist -s')
    end

    task :kickstart_sha do
      KICKSTART_SHA = 'master' if ENV['KICKSTART_SHA'].nil?
    end

    desc "Perform the vsphere brew image build without installing cfme for diagnosing package dependencies"
    task :no_cfme_vsphere => [:kerberos_init, :kickstart_sha] do
      raise "must set ENV['PUDDLE'] to point to the source RPMs" if ENV['PUDDLE'].nil?
      config_file = File.join(File.dirname(__FILE__), 'build/productization/config/image_build_vsphere')
      system(brew_cmd(config_file, "no-cfme-vsphere.ks"))
    end

    desc "Perform the vsphere brew image build"
    task :vsphere => [:kerberos_init, :kickstart_sha] do
      raise "must set ENV['PUDDLE'] to point to the source RPMs" if ENV['PUDDLE'].nil?
      config_file = File.join(File.dirname(__FILE__), 'build/productization/config/image_build_vsphere')
      system(brew_cmd(config_file, "base-vsphere.ks"))
    end

    desc "Perform the rhevm brew image build"
    task :rhevm => [:kerberos_init, :kickstart_sha] do
      raise "must set ENV['PUDDLE'] to point to the source RPMs" if ENV['PUDDLE'].nil?
      config_file = File.join(File.dirname(__FILE__), 'build/productization/config/image_build_rhevm')
      system(brew_cmd(config_file, "base-rhevm.ks"))
    end

    desc "Perform the rhos brew image build"
    task :rhos => [:kerberos_init, :kickstart_sha] do
      raise "must set ENV['PUDDLE'] to point to the source RPMs" if ENV['PUDDLE'].nil?
      config_file = File.join(File.dirname(__FILE__), 'build/productization/config/image_build_rhos')
      system(brew_cmd(config_file, "base-rhos.ks"))
    end

    desc "Perform all of the brew image builds, excluding no_cfme_vsphere"
    task :all do
      ['build:image:vsphere', 'build:image:rhevm', 'build:image:rhos'].each { |t| Rake::Task[t].invoke }
    end

  end

end
