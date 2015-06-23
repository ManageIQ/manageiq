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
