require 'awesome_spawn'
require "vmdb/plugins"

namespace :evm do
  namespace :ansible_runner do
    desc "Seed galaxy roles for provider playbooks"
    task :seed do
      plugins_with_req_yml = Vmdb::Plugins.select do |plugin|
        req_yml_path = plugin.root.join('content_tmp', 'ansible', 'requirements.yml')
        File.file?(req_yml_path)
      end

      plugins_with_req_yml.each do |plugin|
        puts "Seeding roles for #{plugin.name}..."

        roles_path = plugin.root.join('content_tmp', 'ansible', 'roles')
        role_file  = plugin.root.join('content_tmp', 'ansible', 'requirements.yml')

        params = ["install", :roles_path= => roles_path, :role_file= => role_file]

        begin
          AwesomeSpawn.run!("ansible-galaxy", :params => params)
          puts "Seeding roles for #{plugin.name}...Complete"
        rescue AwesomeSpawn::CommandResultError => err
          puts "Seeding roles for #{plugin.name}...Failed - #{err.result.error}"
          raise
        end
      end
    end
  end
end
