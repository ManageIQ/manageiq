require Rails.root.join('db/fixtures/ae_datastore/ManageIQ/Cloud/Orchestration/Operations' \
                        '/Methods.class/__methods__/available_os_types.rb').to_s

describe ManageIQ::Automate::Cloud::Orchestration::Operations::AvailableOsTypes do
  os_list = {'unknown' => '<Unknown>', 'linux' => 'Linux', 'windows' => 'Windows'}
  let(:service_template) do
    hw1 = FactoryGirl.create(:hardware, :guest_os => 'windows')
    img1 = FactoryGirl.create(:template_openstack, :uid_ems => 'uid1', :hardware => hw1)

    hw2 = FactoryGirl.create(:hardware, :guest_os => 'linux')
    img2 = FactoryGirl.create(:template_openstack, :uid_ems => 'uid2', :hardware => hw2)

    ems = FactoryGirl.create(:ems_openstack, :miq_templates => [img1, img2])
    FactoryGirl.create(:service_template_orchestration, :orchestration_manager => ems)
  end
  let(:root_hash) do
    { 'service_template' => MiqAeMethodService::MiqAeServiceServiceTemplate.find(service_template.id) }
  end
  let(:root_object) { Spec::Support::MiqAeMockObject.new(root_hash) }
  let(:ae_service) do
    Spec::Support::MiqAeMockService.new(root_object).tap do |service|
      current_object = Spec::Support::MiqAeMockObject.new
      current_object.parent = root_object
      service.object = current_object
    end
  end

  it "provides all os types and default to unknown" do
    described_class.new(ae_service).main

    expect(ae_service["values"]).to include(os_list)
    expect(ae_service["default_value"]).to eq('unknown')
  end

  it "provides all os types and auto selects the type based on the user selection of an image" do
    ae_service.root["dialog_param_userImageName"] = 'uid1'
    described_class.new(ae_service).main

    expect(ae_service["values"]).to include(os_list)
    expect(ae_service["default_value"]).to eq('windows')
  end
end
