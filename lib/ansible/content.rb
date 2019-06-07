module Ansible
  class Content
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
  end
end
