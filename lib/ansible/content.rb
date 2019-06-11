module Ansible
  class Content
    PLUGIN_CONTENT_DIR = Rails.root.join("content", "ansible_consolidated").to_s.freeze

    attr_accessor :path

    def initialize(path)
      @path = path
    end

    def fetch_galaxy_roles
      roles_path = path.join('roles')
      role_file  = path.join('requirements.yml')

      params = ["install", :roles_path= => roles_path, :role_file= => role_file]
      AwesomeSpawn.run!("ansible-galaxy", :params => params)
    end

    def self.consolidate_plugin_playbooks(dir = PLUGIN_CONTENT_DIR)
      FileUtils.rm_rf(dir)
      FileUtils.mkdir_p(dir)

      Vmdb::Plugins.ansible_content.each do |content|
        FileUtils.cp_r(Dir.glob("#{content.path}/*"), dir)
      end
    end
  end
end
