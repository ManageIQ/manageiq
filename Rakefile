namespace :build do
  desc "Upload the build files to an imagefactory instance"
  task :upload do
    raise "must set ENV['SCP_USER_HOST'], such as root@your_host" if ENV['SCP_USER_HOST'].nil?

    require 'pathname'
    build_dir = Pathname.new(File.join(File.dirname(__FILE__), 'build'))

    `ssh #{ENV['SCP_USER_HOST']} "rm -rf ~/manageiq && mkdir -p ~/manageiq"`
    `scp -qr #{build_dir} #{ENV['SCP_USER_HOST']}:~/manageiq/build`
  end
end
