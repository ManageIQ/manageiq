require 'awesome_spawn'
require "vmdb/plugins"

namespace :evm do
  namespace :ansible_runner do
    desc "Seed galaxy roles for provider playbooks"
    task :seed do
      Vmdb::Plugins.ansible_runner_content.each do |plugin, content_dir|
        puts "Seeding roles for #{plugin.name}..."

        roles_path = content_dir.join('roles')
        role_file  = content_dir.join('requirements.yml')

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
