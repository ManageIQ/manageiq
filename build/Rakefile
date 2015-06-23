require_relative 'productization'

namespace :build do

  module FilePaths
    BUILD        = Pathname.new(File.dirname(__FILE__)).join("../vmdb/BUILD")
    VERSION      = Pathname.new(File.dirname(__FILE__)).join("../vmdb/VERSION")
  end

  class ConfigOptions
    require "yaml"
    include FilePaths
    def self.options
      @options ||= YAML.load_file(Build::Productization.file_for("config/tarball/options.yml"))
    end

    def self.version
      ENV["VERSION_ENV"] || options[:version] || File.read(VERSION).chomp
    end

    def self.prefix
      options[:name_prefix]
    end
  end

  task :build_file do
    date    = Time.now.strftime("%Y%m%d%H%M%S")
    git_sha = `git rev-parse --short HEAD`
    build   = "#{ConfigOptions.version}-#{date}_#{git_sha}"
    File.write(FilePaths::BUILD, build)
  end

  task :version_files do
    File.write(FilePaths::VERSION, "#{ConfigOptions.version}\n")
  end

  task :precompile_assets do
    Dir.chdir(File.expand_path(File.join(File.dirname(__FILE__), '..', 'vmdb')))
    puts `bundle exec rake evm:compile_assets`
    Dir.chdir(File.dirname(__FILE__))
  end

  desc "Builds a tarball."
  task :tar => [:version_files, :build_file, :precompile_assets] do
    include_file = Build::Productization.file_for("config/tarball/include")
    exclude_file = Build::Productization.file_for("config/tarball/exclude")
    pkg_path     = Pathname.new(File.dirname(__FILE__)).join("pkg")
    FileUtils.mkdir_p(pkg_path)

    tar_basename = "#{ConfigOptions.prefix}-#{ConfigOptions.version}"
    tarball = "pkg/#{tar_basename}.tar.gz"

    # Add a prefix-version directory to the top of the files added to the tar.
    # This is needed by rpm tooling.
    transform = RUBY_PLATFORM =~ /darwin/ ? "-s " : "--transform s"
    transform << "',^,#{tar_basename}/,'"

    `tar -C .. #{transform} -T #{include_file} -X #{exclude_file} -hcvzf #{tarball}`
    puts "Built tarball at:\n #{File.expand_path(tarball)}"
  end
end

task :default => "build:tar"
