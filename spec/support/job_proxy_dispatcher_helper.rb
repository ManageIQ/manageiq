module Spec
  module Support
    module JobProxyDispatcherHelper
      def build_entities(options = {})
        options = {:hosts => 2, :storages => 2, :vms => 3, :repo_vms => 3, :container_providers => [1, 2]}.merge(options)

        proxies = []
        storages = []
        options[:storages].times do |i|
          storage = FactoryGirl.create(:storage, :name => "test_storage_#{i}", :store_type => "VMFS")
          storages << storage
        end

        ems = FactoryGirl.create(:ems_vmware, :name => "ems1")
        hosts = []
        options[:hosts].times do |i|
          host = FactoryGirl.create(:host, :name => "test_host_#{i}", :hostname => "test_host_#{i}")
          max = i > storages.length ? storages.length : i
          host.storages = storages[0..max]
          host.ext_management_system = ems
          host.save
          hosts << host
        end

        vms = []
        options[:vms].times do |i|
          vm = FactoryGirl.create(:vm_vmware, :name => "test_vm_#{i}", :location => "abc/abc.vmx")
          vm.storage = storages[(i % options[:storages])]
          vm.host = hosts[(i % options[:hosts])]
          vm.ext_management_system = ems
          vm.save
          vms << vm
        end

        repo_vms = []

        repo_storage = FactoryGirl.create(:storage, :name => "test_repo_storage", :store_type => "VMFS")
        repo_storage.hosts = []
        repo_storage.save

        options[:repo_vms].times do |i|
          vm = FactoryGirl.create(:vm_vmware, :name => "test_repo_vm_#{i}", :location => "abc/abc.vmx")
          vm.storage = repo_storage
          vm.host = nil
          vm.save
          repo_vms << vm
        end

        container_providers = []
        options[:container_providers].each_with_index do |images_count, i|
          ems_kubernetes = FactoryGirl.create(:ems_kubernetes, :name => "test_container_provider_#{i}")
          container_providers << ems_kubernetes
          images_count.times do |idx|
            FactoryGirl.create(:container_image, :name => "test_container_images_#{idx}", :ems_id => ems_kubernetes.id)
          end
        end
        return hosts, proxies, storages, vms, repo_vms, container_providers
      end
    end
  end
end
