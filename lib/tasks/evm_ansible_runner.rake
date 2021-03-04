namespace :evm do
  namespace :ansible_runner do
    desc "Seed plugin ansible content and galaxy roles"
    task :seed do
      require "ansible/content"

      puts "Fetching ansible galaxy roles for plugins..."
      Ansible::Content.fetch_plugin_galaxy_roles
      puts "Fetching ansible galaxy roles for plugins...Complete"

      puts "Consolidating plugin ansible content..."
      Ansible::Content.consolidate_plugin_content
      puts "Consolidating plugin ansible content...Complete"
    end
  end
end
