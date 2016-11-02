require 'rake'

# Tasks for regenerating cassettes and running tests for the Azure
# solid state stuff. You should run these while in the gems/pending
# subdirectory.
#
# The tasks that regenerate cassettes assume that you have cloned the
# gems-pending-config project to your $HOME/Dev directory.

namespace 'azure' do
  namespace 'record' do
    env_dir = File.join(Dir.home, 'Dev', 'gems-pending-config')

    desc 'Recreate the Azure blob disk cassettes'
    task :disk do
      yaml_dir = File.join(Rake.original_dir, 'spec/recordings/disk/modules/azure_blob_disk_spec')
      Dir["#{yaml_dir}/*.yml"].each { |f| FileUtils.rm_rf(f) }
      sh "TEST_ENV_DIR=#{env_dir} bundle exec rspec spec/disk/modules/azure_blob_disk_spec.rb"
    end

    desc 'Recreate the Azure VM image cassettes'
    task :vm_image do
      yaml_dir = File.join(Rake.original_dir, 'spec/recordings/miq_vm/miq_azure_vm_image_spec')
      Dir["#{yaml_dir}/*.yml"].each { |f| FileUtils.rm_rf(f) }
      sh "TEST_ENV_DIR=#{env_dir} bundle exec rspec spec/miq_vm/miq_azure_vm_image_spec.rb"
    end

    desc 'Recreate the Azure VM instance cassettes'
    task :vm_instance do
      yaml_dir = File.join(Rake.original_dir, 'spec/recordings/miq_vm/miq_azure_vm_instance_spec')
      Dir["#{yaml_dir}/*.yml"].each { |f| FileUtils.rm_rf(f) }
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
