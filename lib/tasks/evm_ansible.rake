require 'awesome_spawn'
require "vmdb/plugins"

namespace :evm do
  namespace :ansible do
    desc "Seed galaxy roles for provider playbooks"
    task :seed do
      plugins_with_req_yml = Vmdb::Plugins.select do |p|
        req_yml_path = p.root.join('content_tmp', 'ansible', 'requirements.yml')
        File.file?(req_yml_path)
      end

      plugins_with_req_yml.each do |p|
        puts "Seeding roles for #{p.name.split("::Engine").first}..."

        roles_path = p.root.join('content_tmp', 'ansible', 'roles')
        role_file  = p.root.join('content_tmp', 'ansible', 'requirements.yml')

        AwesomeSpawn.run!(
          "ansible-galaxy",
          :params => {
            nil          => "install",
            :roles_path= => roles_path,
            :role_file=  => role_file
          }
        )
        puts "Seeding roles for #{p.name.split("::Engine").first}...Complete"
      end
    end
  end
end
