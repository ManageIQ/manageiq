module Ansible
  class Content
    PLUGIN_CONTENT_DIR = Rails.root.join("content/ansible_consolidated").to_s.freeze

    attr_accessor :path

    def initialize(path)
      @path = Pathname.new(path)
    end

    def fetch_galaxy_roles
      return true unless requirements_file.exist?

      require "awesome_spawn"
      AwesomeSpawn.run!("ansible-galaxy", :params => ["install", {:roles_path= => roles_dir, :role_file= => requirements_file}])
    end

    def self.fetch_plugin_galaxy_roles
      require "vmdb/plugins"

      Vmdb::Plugins.ansible_runner_content.each do |plugin, content_dir|
        puts "Fetching ansible galaxy roles for #{plugin.name}..."
        begin
          new(content_dir).fetch_galaxy_roles
          puts "Fetching ansible galaxy roles for #{plugin.name}...Complete"
        rescue AwesomeSpawn::CommandResultError => err
          puts "Fetching ansible galaxy roles for #{plugin.name}...Failed - #{err.result.error}"
          raise
        end
      end
    end

    def self.consolidate_plugin_content(dir = PLUGIN_CONTENT_DIR)
      require "vmdb/plugins"

      FileUtils.rm_rf(dir)
      FileUtils.mkdir_p(dir)

      Vmdb::Plugins.ansible_content.each do |content|
        FileUtils.cp_r(Dir.glob("#{content.path}/*"), dir)
      end
    end

    private

    def roles_dir
      @roles_dir ||= path.join('roles')
    end

    def requirements_file
      @requirements_file ||= roles_dir.join('requirements.yml')
    end
  end
end
