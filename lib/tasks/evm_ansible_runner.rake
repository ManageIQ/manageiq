namespace :evm do
  namespace :ansible_runner do
    desc "Seed galaxy roles for provider playbooks"
    task :seed do
      require 'awesome_spawn'
      require "vmdb/plugins"
      require 'ansible/content'

      Vmdb::Plugins.ansible_runner_content.each do |plugin, content_dir|
        content = Ansible::Content.new(content_dir)

        puts "Seeding roles for #{plugin.name}..."
        begin
          content.fetch_galaxy_roles
          puts "Seeding roles for #{plugin.name}...Complete"
        rescue AwesomeSpawn::CommandResultError => err
          puts "Seeding roles for #{plugin.name}...Failed - #{err.result.error}"
          raise
        end
      end
    end
  end
end
