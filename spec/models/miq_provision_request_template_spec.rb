describe MiqProvisionRequestTemplate do
  let(:user)             { FactoryGirl.create(:user) }
  let(:template)         do
    FactoryGirl.create(:template_vmware,
                       :ext_management_system => FactoryGirl.create(:ems_vmware_with_authentication))
  end
  let(:parent_svc)       { FactoryGirl.create(:service, :guid => MiqUUID.new_guid) }
  let(:service_resource) { FactoryGirl.create(:service_resource) }
  let(:service_template_request) { FactoryGirl.create(:service_template_provision_request, :requester => user) }
  let(:service_task) do
    FactoryGirl.create(:service_template_provision_task,
                       :miq_request  => service_template_request,
                       :options      => {:service_resource_id => service_resource.id})
  end
  let(:provision_request_template) do
    FactoryGirl.create(:miq_provision_request_template,
                       :requester    => user,
                       :src_vm_id    => template.id,
                       :options      => {
                         :src_vm_id           => template.id,
                         :service_resource_id => service_resource.id
                       })
  end

  describe '#create_tasks_for_service' do
    before do
      MiqRegion.seed
      allow_any_instance_of(ManageIQ::Providers::Vmware::InfraManager::Provision).to receive(:get_hostname).and_return('hostname')
      allow(MiqAeEngine).to receive(:resolve_automation_object).and_return(double(:root => 'miq'))
    end

    it 'should only call get_next_vm_name once' do
      expect_any_instance_of(ManageIQ::Providers::Vmware::InfraManager::Provision).to receive(:get_next_vm_name).once.and_call_original

      provision_request_template.create_tasks_for_service(service_task, parent_svc)
    end

    it 'should create sequenced VM names' do
      task1 = provision_request_template.create_tasks_for_service(service_task, parent_svc).first
      expect(task1.options[:vm_target_name]).to eq('miq_0001')

      task2 = provision_request_template.create_tasks_for_service(service_task, parent_svc).first
      expect(task2.options[:vm_target_name]).to eq('miq_0002')
    end

    it 'assign task to a request' do
      task = provision_request_template.create_tasks_for_service(service_task, parent_svc).first
      expect(task.miq_request).to eq(service_template_request)
    end

    describe "scaling_min" do
      it "runs once with scaling min nil" do
        service_resource.update_attributes(:scaling_min => nil)
        expect(provision_request_template.create_tasks_for_service(service_task, parent_svc).count).to eq(1)
      end

      it "runs never with scaling min 0" do
        service_resource.update_attributes(:scaling_min => 0)
        expect(provision_request_template.create_tasks_for_service(service_task, parent_svc).count).to eq(0)
      end

      it "runs twice with scaling min 2" do
        service_resource.update_attributes(:scaling_min => 2)
        expect(provision_request_template.create_tasks_for_service(service_task, parent_svc).count).to eq(2)
      end
    end

    it "does not modify owner in options" do
      task = provision_request_template.create_tasks_for_service(service_task, parent_svc).first

      expect(task.options[:owner_email]).to be_nil
    end

    context "with service_task user" do
      let(:user) { FactoryGirl.create(:user_with_email) }

      it "sets owner in options" do
        service_task.update_attributes(:userid => user.userid)
        task = provision_request_template.create_tasks_for_service(service_task, parent_svc).first

        expect(task.options[:owner_email]).to eq(user.email)
      end
    end
  end
end
