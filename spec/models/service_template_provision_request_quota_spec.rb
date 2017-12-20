describe ServiceTemplateProvisionRequest do
  include Spec::Support::QuotaHelper
  include Spec::Support::ServiceTemplateHelper

  let(:admin) { FactoryGirl.create(:user_admin) }
  context "quota methods" do
    context "for cloud and infra providers," do
      def create_task(user, request)
        FactoryGirl.create(:service_template_provision_task, :miq_request => request, :miq_request_id => request.id, :type => 'ServiceTemplateProvisionTask', :description => "task", :tenant => user.current_tenant)
      end

      def create_request(user, template, prov_options = {})
        FactoryGirl.create(:service_template_provision_request, :requester   => user,
                                                                :description => "request",
                                                                :tenant_id   => user.current_tenant.id,
                                                                :source_type => "ServiceTemplate",
                                                                :source_id   => template.id,
                                                                :process     => true,
                                                                :options     => prov_options.merge(:owner_email => user.email))
      end

      def request_queue_entry(request)
        FactoryGirl.create(:miq_queue,
                           :state       => MiqQueue::STATE_DEQUEUE,
                           :instance_id => request.id,
                           :class_name  => 'ServiceTemplateProvisionRequest',
                           :method_name => 'create_request_tasks')
      end

      def task_queue_entry(task)
        FactoryGirl.create(:miq_queue,
                           :state          => MiqQueue::STATE_DEQUEUE,
                           :args           => [{:object_type => "ServiceTemplateProvisionRequest", :object_id => task.id}],
                           :tracking_label => 'service_template_provision_task',
                           :class_name     => 'MiqAeEngine',
                           :method_name    => 'deliver')
      end

      def create_test_task(user, service_template)
        request = create_request(user, service_template)
        create_task(user, request)
        request
      end

      def queue(requests)
        requests.each do |request|
          request.miq_request_tasks.empty? ? request_queue_entry(request) : task_queue_entry(request.miq_request_tasks.first)
        end
      end

      def create_service_bundle(user, items, options = {})
        build_model_from_vms(items)
        request = build_service_template_request("top", user, :dialog => {"test" => "dialog"})
        res = request.service_template.service_resources.first.resource.service_resources.first.resource
        res.options.merge!(options)
        res.save
        request
      end

      shared_examples_for "check_quota" do
        it "check" do
          load_queue
          stats = request.check_quota(quota_method)
          expect(stats).to include(counts_hash)
        end
      end

      context "infra," do
        let(:vmware_tasks) do
          ems = FactoryGirl.create(:ems_vmware)
          group = FactoryGirl.create(:miq_group, :tenant => FactoryGirl.create(:tenant))
          @vmware_user1 = FactoryGirl.create(:user_with_email, :miq_groups => [group])
          @vmware_user2 = FactoryGirl.create(:user_with_email, :miq_groups => [group])
          @vmware_template = FactoryGirl.create(:template_vmware,
                                                :ext_management_system => ems,
                                                :hardware              => FactoryGirl.create(:hardware, :cpu1x2, :memory_mb => 512))
          @vmware_prov_options = {:number_of_vms => [2, '2'], :vm_memory => [1024, '1024'], :number_of_cpus => [2, '2']}
          requests = []

          @vm_template = @vmware_template

          @user = @vmware_user1
          requests << build_vmware_service_item

          requests << create_service_bundle(@user, [@vmware_template], @vmware_prov_options)
          create_task(@user, requests.last)

          @user = @vmware_user2
          requests << build_vmware_service_item
          create_task(@user, requests.last)

          requests << create_service_bundle(@user, [@vmware_template], @vmware_prov_options)

          requests.each { |r| r.update_attributes(:tenant_id => @user.current_tenant.id) }
          requests
        end

        let(:load_queue) { queue(vmware_tasks) }
        let(:request) { create_test_task(@vmware_user1, @vmware_template) }
        let(:counts_hash) do
          {:count => 6, :memory => 6.gigabytes, :cpu => 16, :storage => 3.gigabytes}
        end

        context "active_provisions_by_tenant," do
          let(:quota_method) { :active_provisions_by_tenant }
          it_behaves_like "check_quota"
        end

        context "active_provisions_by_group," do
          let(:quota_method) { :active_provisions_by_group }
          it_behaves_like "check_quota"
        end

        context "active_provisions_by_owner," do
          let(:quota_method) { :active_provisions_by_owner }
          let(:counts_hash) do
            {:count => 3, :memory => 3.gigabytes, :cpu => 8, :storage => 1_610_612_736}
          end
          it_behaves_like "check_quota"

          it "fails without requester.email" do
            load_queue
            @vmware_user1.update_attributes(:email => nil)
            expect { request.check_quota(quota_method) }.to raise_error(NoMethodError)
          end
        end
      end

      context "cloud," do
        def build_google_service_item
          options = {:requester => @user}.merge(@google_prov_options)
          model = {"google_service_item" => {:type      => 'atomic',
                                             :prov_type => 'google',
                                             :request   => options}}
          build_service_template_tree(model)
          @service_request = build_service_template_request("google_service_item", @user, :dialog => {"test" => "dialog"})
        end

        let(:google_tasks) do
          ems = FactoryGirl.create(:ems_google_with_authentication,
                                   :availability_zones => [FactoryGirl.create(:availability_zone_google)])
          group = FactoryGirl.create(:miq_group, :tenant => FactoryGirl.create(:tenant))
          @google_user1 = FactoryGirl.create(:user_with_email, :miq_groups => [group])
          @google_user2 = FactoryGirl.create(:user_with_email, :miq_groups => [group])

          @google_template = FactoryGirl.create(:template_google, :ext_management_system => ems)
          flavor = FactoryGirl.create(:flavor_google, :ems_id => ems.id,
                                      :cpus => 4, :cpu_cores => 1, :memory => 1024)
          @google_prov_options = {:number_of_vms => [1, '1'], :src_vm_id => @google_template.id, :boot_disk_size => ["10.GB", "10 GB"],
                          :placement_auto => [true, 1], :instance_type => [flavor.id, flavor.name]}
          requests = []

          @vm_template = @google_template

          @user = @google_user1
          requests << build_google_service_item

          requests << create_service_bundle(@user, [@google_template], @google_prov_options)
          create_task(@user, requests.last)

          @user = @google_user2
          requests << build_google_service_item
          create_task(@user, requests.last)

          requests << create_service_bundle(@user, [@google_template], @google_prov_options)

          requests.each { |r| r.update_attributes(:tenant_id => @user.current_tenant.id) }
          requests
        end

        let(:load_queue) { queue(google_tasks) }
        let(:request) { create_test_task(@google_user1, @google_template) }
        let(:counts_hash) do
          {:count => 4, :memory => 4096, :cpu => 16, :storage => 40.gigabytes}
        end

        context "active_provisions_by_tenant," do
          let(:quota_method) { :active_provisions_by_tenant }
          it_behaves_like "check_quota"
        end

        context "active_provisions_by_group," do
          let(:quota_method) { :active_provisions_by_group }
          it_behaves_like "check_quota"
        end

        context "active_provisions_by_owner," do
          let(:quota_method) { :active_provisions_by_owner }
          let(:counts_hash) do
            {:count => 2, :memory => 2048, :cpu => 8, :storage => 20.gigabytes}
          end
          it_behaves_like "check_quota"
        end
      end
    end
  end
end
