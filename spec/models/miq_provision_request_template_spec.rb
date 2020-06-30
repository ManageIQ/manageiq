RSpec.describe MiqProvisionRequestTemplate do
  let(:user)             { FactoryBot.create(:user) }
  let(:template)         do
    FactoryBot.create(:template_vmware,
                       :ext_management_system => FactoryBot.create(:ems_vmware_with_authentication))
  end
  let(:parent_svc) { FactoryBot.create(:service, :guid => SecureRandom.uuid, :options => {:dialog => {}}) }
  let(:bundle_parent_svc) do
    FactoryBot.create(:service, :guid => SecureRandom.uuid, :options => {:dialog => {}})
  end
  let(:service_resource) do
    FactoryBot.create(:service_resource,
                       :resource_type => 'MiqRequest',
                       :resource_id   => service_template_request.id)
  end
  let(:service_template) do
    FactoryBot.create(:service_template)
  end
  let(:bundle_service_template) do
    FactoryBot.create(:service_template)
  end
  let(:service_template_resource) do
    FactoryBot.create(:service_resource,
                       :resource_type => 'ServiceTemplate',
                       :resource_id   => service_template.id)
  end
  let(:bundle_service_template_resource) do
    FactoryBot.create(:service_resource,
                       :resource_type => 'ServiceTemplate',
                       :resource_id   => bundle_service_template.id)
  end
  let(:service_template_request) { FactoryBot.create(:service_template_provision_request, :requester => user) }
  let(:service_task) do
    FactoryBot.create(:service_template_provision_task,
                       :miq_request  => service_template_request,
                       :options      => {:service_resource_id => service_resource.id})
  end
  let(:parent_service_task) do
    FactoryBot.create(:service_template_provision_task,
                       :status       => 'Ok',
                       :state        => 'pending',
                       :request_type => 'clone_to_service',
                       :miq_request  => service_template_request,
                       :options      => {:service_resource_id => service_template_resource.id})
  end
  let(:bundle_service_task) do
    FactoryBot.create(:service_template_provision_task,
                       :status       => 'Ok',
                       :state        => 'pending',
                       :request_type => 'clone_to_service',
                       :miq_request  => service_template_request,
                       :options      => {:service_resource_id => bundle_service_template_resource.id})
  end
  let(:provision_request_template) do
    FactoryBot.create(:miq_provision_request_template,
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
      expect(task1.options[:vm_target_name]).to eq('miq0001')

      task2 = provision_request_template.create_tasks_for_service(service_task, parent_svc).first
      expect(task2.options[:vm_target_name]).to eq('miq0002')
    end

    it 'assign task to a request' do
      task = provision_request_template.create_tasks_for_service(service_task, parent_svc).first
      expect(task.miq_request).to eq(service_template_request)
    end

    describe "scaling_min" do
      it "runs once with scaling min nil" do
        service_resource.update(:scaling_min => nil)
        expect(provision_request_template.create_tasks_for_service(service_task, parent_svc).count).to eq(1)
      end

      it "runs never with scaling min 0" do
        service_resource.update(:scaling_min => 0)
        expect(provision_request_template.create_tasks_for_service(service_task, parent_svc).count).to eq(0)
      end

      it "runs twice with scaling min 2" do
        service_resource.update(:scaling_min => 2)
        expect(provision_request_template.create_tasks_for_service(service_task, parent_svc).count).to eq(2)
      end

      it "use number_of_vms from request" do
        service_template_request.options[:number_of_vms] = 3
        service_template_request.save!
        expect(provision_request_template.create_tasks_for_service(service_task, parent_svc).count).to eq(3)
      end

      it "use number of vms from dialogs" do
        parent_svc.options[:dialog] = {"dialog_option_number_of_vms" => 5}
        service_task.options[:parent_task_id] = parent_service_task.id
        expect(provision_request_template.create_tasks_for_service(service_task, parent_svc).count).to eq(5)
      end

      it "use number of vms from bundle dialogs" do
        bundle_parent_svc.options[:dialog] = {"dialog_option_1_number_of_vms" => 7}
        parent_svc.parent = bundle_parent_svc
        bundle_parent_svc.save!
        parent_service_task.options[:parent_task_id] = bundle_service_task.id
        service_task.options[:parent_task_id] = parent_service_task.id
        expect(provision_request_template.create_tasks_for_service(service_task, parent_svc).count).to eq(7)
      end

      it "use number of vms from bundle dialogs override" do
        bundle_parent_svc.options[:dialog] = {"dialog_option_1_number_of_vms" => 7,
                                              "dialog_option_0_number_of_vms" => 8}
        parent_svc.parent = bundle_parent_svc
        bundle_parent_svc.save!
        parent_service_task.options[:parent_task_id] = bundle_service_task.id
        service_task.options[:parent_task_id] = parent_service_task.id
        expect(provision_request_template.create_tasks_for_service(service_task, parent_svc).count).to eq(8)
      end
    end

    it "does not modify owner in options" do
      task = provision_request_template.create_tasks_for_service(service_task, parent_svc).first

      expect(task.options[:owner_email]).to be_nil
    end

    context "with service_task user" do
      let(:user) { FactoryBot.create(:user_with_email) }

      it "sets owner in options" do
        service_task.update(:userid => user.userid)
        task = provision_request_template.create_tasks_for_service(service_task, parent_svc).first

        expect(task.options[:owner_email]).to eq(user.email)
      end
    end
  end

  describe "post_create" do
    it 'sets description' do
      expect(MiqAeEngine).not_to receive(:resolve_automation_object)

      provision_request_template.post_create(true)

      expect(provision_request_template.description).to eq("Miq Provision Request Template for #{provision_request_template.source.name}")
    end
  end

  it 'exists after source template is deleted' do
    provision_request_template
    template.destroy
    expect(provision_request_template.reload).not_to be_nil
  end
end
