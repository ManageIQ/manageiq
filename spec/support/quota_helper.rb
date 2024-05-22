module Spec
  module Support
    module QuotaHelper
      def create_category_and_tag(category, tag)
        cat = Classification.lookup_by_name(category)
        cat ||= Classification.create_category!(:name         => category,
                                              :single_value => false,
                                              :description  => category)
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

        @hw1 = FactoryBot.create(:hardware, :cpu_sockets => @num_cpu, :memory_mb => @ram_size)
        @hw2 = FactoryBot.create(:hardware, :cpu_sockets => @num_cpu, :memory_mb => @ram_size)
        @hw3 = FactoryBot.create(:hardware, :cpu_sockets => @num_cpu, :memory_mb => @ram_size)
        @hw4 = FactoryBot.create(:hardware, :cpu_sockets => @num_cpu, :memory_mb => @ram_size)
        create_disks
      end

      def create_disks
        @disk1 = FactoryBot.create(:disk, :device_type => "disk", :size => @disk_size, :hardware_id => @hw1.id)
        @disk2 = FactoryBot.create(:disk, :device_type => "disk", :size => @disk_size, :hardware_id => @hw2.id)
        @disk3 = FactoryBot.create(:disk, :device_type => "disk", :size => @disk_size, :hardware_id => @hw3.id)
        @disk3 = FactoryBot.create(:disk, :device_type => "disk", :size => @disk_size, :hardware_id => @hw4.id)
      end

      def create_tenant_quota
        @tenant.tenant_quotas.create(:name => :mem_allocated, :value => 2048)
        @tenant.tenant_quotas.create(:name => :vms_allocated, :value => 4)
        @tenant.tenant_quotas.create(:name => :storage_allocated, :value => 4096)
        @tenant.tenant_quotas.create(:name => :cpu_allocated, :value => 2)
        @tenant.tenant_quotas.create(:name => :templates_allocated, :value => 4)
      end

      def create_vmware_vms
        @active_vm = FactoryBot.create(:vm_vmware,
                                        :miq_group_id => @miq_group.id,
                                        :evm_owner_id => @user.id,
                                        :ems_id       => @ems.id,
                                        :storage_id   => @storage.id,
                                        :hardware     => @hw1,
                                        :tenant       => @tenant)
        @archived_vm = FactoryBot.create(:vm_vmware,
                                          :miq_group_id => @miq_group.id,
                                          :evm_owner_id => @user.id,
                                          :hardware     => @hw2)
        @orphaned_vm = FactoryBot.create(:vm_vmware,
                                          :miq_group_id => @miq_group.id,
                                          :evm_owner_id => @user.id,
                                          :storage_id   => @storage.id,
                                          :hardware     => @hw3)
        @retired_vm = FactoryBot.create(:vm_vmware,
                                         :miq_group_id => @miq_group.id,
                                         :evm_owner_id => @user.id,
                                         :retired      => true,
                                         :hardware     => @hw4)
      end

      def create_google_vms
        @active_vm = FactoryBot.create(:vm_google,
                                        :miq_group_id          => @miq_group.id,
                                        :evm_owner_id          => @user.id,
                                        :ext_management_system => @ems,
                                        :tenant                => @tenant)
        @archived_vm = FactoryBot.create(:vm_google,
                                          :miq_group_id => @miq_group.id,
                                          :evm_owner_id => @user.id,
                                          :tenant       => @tenant)
        @orphaned_vm = FactoryBot.create(:vm_google,
                                          :miq_group_id => @miq_group.id,
                                          :evm_owner_id => @user.id,
                                          :tenant       => @tenant)
        @retired_vm = FactoryBot.create(:vm_google,
                                         :miq_group_id => @miq_group.id,
                                         :evm_owner_id => @user.id,
                                         :retired      => true,
                                         :tenant       => @tenant)
      end

      def create_request(prov_options)
        @miq_provision_request = FactoryBot.create(:miq_provision_request,
                                                    :requester => @user,
                                                    :source    => @vm_template,
                                                    :options   => prov_options)
        @miq_request = @miq_provision_request
      end

      def vmware_requested_quota_values
        {:number_of_vms     => 1,
         :owner_email       => 'tester@miq.com',
         :vm_memory         => [1024, '1024'],
         :number_of_sockets => [2, '2'],
         :cores_per_socket  => [2, '2']}
      end

      def vmware_template
        @ems = FactoryBot.create(:ems_vmware)
        FactoryBot.create(:template_vmware,
                           :hardware => FactoryBot.create(:hardware, :cpu1x2, :memory_mb => 512))
      end

      def vmware_model
        @vm_template = vmware_template
        @storage = FactoryBot.create(:storage_nfs)
        create_request(vmware_requested_quota_values)
        create_hardware
        create_vmware_vms
      end

      def vmware_reconfigure_model
        @ems = FactoryBot.create(:ems_vmware)
        @storage = FactoryBot.create(:storage_nfs)
        create_hardware
        create_vmware_vms
        @reconfigure_request = FactoryBot.create(:vm_reconfigure_request, :requester => @user)
        @vm_hardware = FactoryBot.build(:hardware, :virtual_hw_version => "07", :cpu_total_cores => 2,
         :memory_mb => 4096, :cpu_sockets => 2, :cpu_cores_per_socket => 1)
        @vm_vmware = FactoryBot.create(:vm_vmware, :hardware => @vm_hardware)
        @vm_vmware.update(:ems_id => @ems.id)
      end

      def google_requested_quota_values
        {:number_of_vms     => 1,
         :instance_type     => [@small_flavor.id, @small_flavor.name],
         :boot_disk_size    => ["10.GB", "10 GB"],
         :placement_auto    => [true, 1],
         :owner_email       => 'tester@miq.com',
         :vm_memory         => [1024, '1024'],
         :number_of_sockets => [2, '2'],
         :st_prov_type      => 'google',
         :cores_per_socket  => [2, '2']}
      end

      def google_template
        @ems = FactoryBot.create(:ems_google_with_authentication,
                                  :availability_zones => [FactoryBot.create(:availability_zone_google)])
        FactoryBot.create(:template_google, :ext_management_system => @ems)
      end

      def google_model
        @vm_template = google_template
        m2_small_flavor = FactoryBot.create(:flavor_google, :ems_id => @ems.id, :cloud_subnet_required => false,
                                             :cpus => 4, :cpu_cores => 1, :memory => 1024)
        create_request(:number_of_vms => 1, :owner_email    => 'user@example.com',
                                            :src_vm_id      => @vm_template.id,
                                            :boot_disk_size => ["10.GB", "10 GB"],
                                            :placement_auto => [true, 1],
                                            :instance_type  => [m2_small_flavor.id, m2_small_flavor.name])
        create_google_vms
      end

      def generic_template
        FactoryBot.create(:service_template,
                           :name         => 'generic',
                           :service_type => 'atomic',
                           :prov_type    => 'generic')
      end

      def build_generic_service_item
        @service_template = generic_template
        @service_request = build_service_template_request("generic", @user, :dialog => {"test" => "dialog"})
      end

      def build_generic_ansible_tower_service_item
        @service_template = FactoryBot.create(:service_template,
                                               :name         => 'generic_ansible_tower',
                                               :service_type => 'atomic',
                                               :prov_type    => 'generic_ansible_tower')
        @service_request = build_service_template_request("generic_ansible_tower", @user,
                                                          :dialog => {"test" => "dialog"})
      end

      def build_vmware_service_item
        options = {:src_vm_id => @vm_template.id, :requester_id => @user.id}.merge(vmware_requested_quota_values)
        model = {"vmware_service_item" => {:type      => 'atomic',
                                           :prov_type => 'vmware',
                                           :request   => options}}
        build_service_template_tree(model)
        @service_request = build_service_template_request("vmware_service_item", @user, :dialog => {"test" => "dialog"})
      end

      def build_google_service_item
        @small_flavor = FactoryBot.create(:flavor_google, :ems_id => @ems.id, :cloud_subnet_required => false,
                                          :cpus => 1, :cpu_cores => 1, :memory => 1024)

        options = {:src_vm_id => @vm_template.id, :requester_id => @user.id}.merge(google_requested_quota_values)
        model = {"google_service_item" => {:type      => 'atomic',
                                           :prov_type => 'google',
                                           :request   => options}}
        build_service_template_tree(model)
        @service_request = build_service_template_request("google_service_item", @user, :dialog => {"test" => "dialog"})
      end

      def create_service_bundle(items)
        user_setup
        create_tenant_quota
        build_model_from_vms(items)
        @service_request = build_service_template_request("top", @user, :dialog => {"test" => "dialog"})
      end

      def user_setup
        @user = FactoryBot.create(:user_with_group)
        @miq_group = @user.current_group
        @tenant = @miq_group.tenant
      end

      def setup_model(vendor = "vmware")
        user_setup
        create_tenant_quota
        send(:"#{vendor}_model") unless vendor == 'generic'
      end
    end
  end
end
