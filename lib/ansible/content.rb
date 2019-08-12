module Ansible
  class Content
    PLUGIN_CONTENT_DIR = Rails.root.join("content", "ansible_consolidated").to_s.freeze

    attr_accessor :path

    def initialize(path)
      @path = Pathname.new(path)
    end

    def fetch_galaxy_roles
      return true unless requirements_file.exist?

      params = ["install", :roles_path= => roles_dir, :role_file= => requirements_file]
      AwesomeSpawn.run!("ansible-galaxy", :params => params)
    end

    def self.consolidate_plugin_playbooks(dir = PLUGIN_CONTENT_DIR)
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
