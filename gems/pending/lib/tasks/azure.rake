require 'rake'
require 'fileutils'

namespace 'azure' do
  desc 'Clone the gem-pending-config git repo (requires VPN access)'
  task 'clone' do
    Dir.chdir(Dir.home) do
      unless File.exist?('gems-pending-config')
        git_repo_url = '' # Paste gitlab URL here
        sh "git clone #{git_repo_url}"
      end
    end
  end

  namespace 'record' do
    env_dir = File.join(Dir.home, 'gems-pending-config')

    desc 'Recreate the Azure blob disk cassettes'
    task :disk => 'azure:clone' do
      # Delete existing yaml files
      yaml_dir = File.join(Rake.original_dir, 'spec/recordings/disk/modules/azure_blob_disk_spec')
      Dir["#{yaml_dir}/*.yml"].each { |f| FileUtils.rm_rf(f) }

      # Run the specs
      sh "TEST_ENV_DIR=#{env_dir} bundle exec rspec spec/disk/modules/azure_blob_disk_spec.rb"
    end

    desc 'Recreate the Azure VM image cassettes'
    task :vm_image => 'azure:clone' do
      # Delete existing yaml files
      yaml_dir = File.join(Rake.original_dir, 'spec/recordings/miq_vm/miq_azure_vm_image_spec')
      Dir["#{yaml_dir}/*.yml"].each { |f| FileUtils.rm_rf(f) }

      # Run the specs
      sh "TEST_ENV_DIR=#{env_dir} bundle exec rspec spec/miq_vm/miq_azure_vm_image_spec.rb"
    end

    desc 'Recreate the Azure VM instance cassettes'
    task :vm_instance => 'azure:clone' do
      # Delete existing yaml files
      yaml_dir = File.join(Rake.original_dir, 'spec/recordings/miq_vm/miq_azure_vm_instance_spec')
      Dir["#{yaml_dir}/*.yml"].each { |f| FileUtils.rm_rf(f) }

      # Run the specs
      sh "TEST_ENV_DIR=#{env_dir} bundle exec rspec spec/miq_vm/miq_azure_vm_instance_spec.rb"
    end
  end

  namespace 'spec' do
    desc 'Run blob disk specs without regenerating cassettes'
    task 'disk' do
      sh "bundle exec rspec spec/disk/modules/azure_blob_disk_spec.rb"
    end

    desc 'Run VM image specs without regenerating cassettes'
    task 'vm_image' do
      sh "bundle exec rspec spec/miq_vm/miq_azure_vm_image_spec.rb"
    end

    desc 'Run VM instance specs without regenerating cassettes'
    task 'vm_instance' do
      sh "bundle exec rspec spec/miq_vm/miq_azure_vm_instance_spec.rb"
    end
  end
end
