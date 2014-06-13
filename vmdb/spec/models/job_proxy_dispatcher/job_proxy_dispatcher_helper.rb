module JobProxyDispatcherHelper

  def build_hosts_proxies_storages_vms(options = {})
    options = {:hosts=>2, :proxies => 2, :storages => 2, :vms => 3, :repo_vms => 3}.merge(options)

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

    proxies = []
    options[:proxies].times do |i|
      proxy = FactoryGirl.create(:active_cos_proxy, :name => "test_cos_proxy_#{i}")
      host = hosts[i]
      host.miq_proxy = proxy
      host.save
      proxies <<  proxy
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
    return hosts, proxies, storages, vms, repo_vms
  end
end
