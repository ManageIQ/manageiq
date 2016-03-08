module QuotaHelper
  def create_category_and_tag(category, tag)
    cat = Classification.find_by_name(category)
    cat = Classification.create_category!(:name         => category,
                                          :single_value => false,
                                          :description  => category) unless cat
    cat.add_entry(:description  => tag,
                  :read_only    => "0",
                  :syntax       => "string",
                  :name         => tag,
                  :example_text => nil,
                  :default      => true,
                  :single_value => "0") if cat
  end

  def setup_tags
    test_values = {:storage => "1024", :vms => "2", :cpu => "2", :memory => "1024"}
    test_values.each do |k, v|
      max_cat = "quota_max_#{k}"
      max_tag = (v.to_i * 2).to_s
      create_category_and_tag(max_cat, max_tag)
      @miq_group.tag_add(max_tag, :ns => "/managed", :cat => max_cat)
      warn_cat = "quota_warn_#{k}"
      warn_tag = v.to_s
      create_category_and_tag(warn_cat, warn_tag)
    end
  end

  def create_hardware
    @ram_size = 1024
    @disk_size = 1_000_000
    @num_cpu = 0

    @hw1 = FactoryGirl.create(:hardware, :cpu_sockets => @num_cpu, :memory_mb => @ram_size)
    @hw2 = FactoryGirl.create(:hardware, :cpu_sockets => @num_cpu, :memory_mb => @ram_size)
    @hw3 = FactoryGirl.create(:hardware, :cpu_sockets => @num_cpu, :memory_mb => @ram_size)
    @hw4 = FactoryGirl.create(:hardware, :cpu_sockets => @num_cpu, :memory_mb => @ram_size)
    create_disks
  end

  def create_disks
    @disk1 = FactoryGirl.create(:disk, :device_type => "disk", :size => @disk_size, :hardware_id => @hw1.id)
    @disk2 = FactoryGirl.create(:disk, :device_type => "disk", :size => @disk_size, :hardware_id => @hw2.id)
    @disk3 = FactoryGirl.create(:disk, :device_type => "disk", :size => @disk_size, :hardware_id => @hw3.id)
    @disk3 = FactoryGirl.create(:disk, :device_type => "disk", :size => @disk_size, :hardware_id => @hw4.id)
  end

  def create_tenant_quota
    @tenant.tenant_quotas.create(:name => :mem_allocated, :value => 2048)
    @tenant.tenant_quotas.create(:name => :vms_allocated, :value => 4)
    @tenant.tenant_quotas.create(:name => :storage_allocated, :value => 4096)
    @tenant.tenant_quotas.create(:name => :cpu_allocated, :value => 2)
    @tenant.tenant_quotas.create(:name => :templates_allocated, :value => 4)
  end

  def create_vms
    @active_vm = FactoryGirl.create(:vm_vmware,
                                    :name         => "Active VM",
                                    :miq_group_id => @miq_group.id,
                                    :ems_id       => @ems.id,
                                    :storage_id   => @storage.id,
                                    :hardware     => @hw1,
                                    :tenant       => @tenant)
    @archived_vm = FactoryGirl.create(:vm_vmware,
                                      :name         => "Archived VM",
                                      :miq_group_id => @miq_group.id,
                                      :hardware     => @hw2)
    @orphaned_vm = FactoryGirl.create(:vm_vmware,
                                      :name         => "Orphaned VM",
                                      :miq_group_id => @miq_group.id,
                                      :storage_id   => @storage.id,
                                      :hardware     => @hw3)
    @retired_vm = FactoryGirl.create(:vm_vmware,
                                     :name         => "Retired VM",
                                     :miq_group_id => @miq_group.id,
                                     :retired      => true,
                                     :hardware     => @hw4)
  end

  def create_storage
    @ems = FactoryGirl.create(:ems_vmware, :name => "test_vcenter")
    @storage = FactoryGirl.create(:storage, :name => "test_storage_nfs", :store_type => "NFS")
  end

  def create_request
    prov_options = {:number_of_vms => 1, :owner_email       => 'tester@miq.com',
                                         :vm_memory         => [1024, '1024'],
                                         :number_of_sockets => [2, '2'],
                                         :cores_per_socket  => [2, '2']}
    @miq_provision_request = FactoryGirl.create(:miq_provision_request,
                                                :requester => @user,
                                                :src_vm_id => @vm_template.id,
                                                :options   => prov_options)
    @miq_request = @miq_provision_request
  end

  def setup_model
    @user = FactoryGirl.create(:user_with_group)
    @miq_group = @user.current_group
    @tenant = @miq_group.tenant

    @vm_template = FactoryGirl.create(:template_vmware,
                                      :name     => "template1",
                                      :hardware => FactoryGirl.create(:hardware, :cpu_sockets => 1, :memory_mb => 512))

    create_tenant_quota
    create_request
    create_storage
    create_hardware
    create_vms
  end
end
