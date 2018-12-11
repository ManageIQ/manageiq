module Spec
  module Support
    module JobProxyDispatcherHelper
      def build_entities(options = {})
        options = {:hosts => 2, :storages => 2, :vms => 3, :repo_vms => 3, :container_providers => [1, 2], :zone => FactoryBot.create(:zone)}.merge(options)

        proxies = []
        storages = []
        options[:storages].times do |i|
          storage = FactoryBot.create(:storage, :name => "test_storage_#{i}", :store_type => "VMFS")
          storages << storage
        end

        ems = FactoryBot.create(:ems_vmware, :name => "ems1", :zone => options[:zone])
        hosts = []
        options[:hosts].times do |i|
          host = FactoryBot.create(:host, :name => "test_host_#{i}", :hostname => "test_host_#{i}")
          max = i > storages.length ? storages.length : i
          host.storages = storages[0..max]
          host.ext_management_system = ems
          host.save
          hosts << host
        end

        vms = []
        options[:vms].times do |i|
          vm = FactoryBot.create(:vm_vmware, :name => "test_vm_#{i}", :location => "abc/abc.vmx")
          vm.storage = storages[(i % options[:storages])]
          vm.host = hosts[(i % options[:hosts])]
          vm.ext_management_system = ems
          vm.save
          vms << vm
        end

        repo_vms = []

        repo_storage = FactoryBot.create(:storage, :name => "test_repo_storage", :store_type => "VMFS")
        repo_storage.hosts = []
        repo_storage.save

        options[:repo_vms].times do |i|
          vm = FactoryBot.create(:vm_vmware, :name => "test_repo_vm_#{i}", :location => "abc/abc.vmx")
          vm.storage = repo_storage
          vm.host = nil
          vm.save
          repo_vms << vm
        end

        container_providers = []
        options[:container_providers].each_with_index do |images_count, i|
          ems_openshift = FactoryBot.create(:ems_openshift, :name => "test_container_provider_#{i}", :zone => options[:zone])
          container_providers << ems_openshift
          container_image_classes = ContainerImage.descendants.append(ContainerImage)
          images_count.times do |idx|
            container_image_classes.each do |cic|
              FactoryBot.create(:container_image,
                                 :name   => "test_container_images_#{idx}",
                                 :ems_id => ems_openshift.id,
                                 :type   => cic.name)
            end
          end
        end
        return hosts, proxies, storages, vms, repo_vms, container_providers
      end
    end
  end
end
