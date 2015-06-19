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

      so_dirs = %w(
        lib/disk/modules/
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
  end
end
