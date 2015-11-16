require 'spec_helper'

describe "Available_Os_Types Method Validation" do
  let(:user) { FactoryGirl.create(:user_with_group) }
  os_list = {'unknown' => '<Unknown>', 'linux' => 'Linux', 'windows' => 'Windows'}
  before do
    @ins = "/Cloud/Orchestration/Operations/Methods/Available_Os_Types"
  end

  let(:service_template) do
    hw1 = FactoryGirl.create(:hardware, :guest_os => 'windows')
    @img1 = FactoryGirl.create(:template_openstack, :uid_ems => 'uid1', :hardware => hw1)

    hw2 = FactoryGirl.create(:hardware, :guest_os => 'linux')
    @img2 = FactoryGirl.create(:template_openstack, :uid_ems => 'uid2', :hardware => hw2)

    ems = FactoryGirl.create(:ems_openstack, :miq_templates => [@img1, @img2])
    FactoryGirl.create(:service_template_orchestration, :orchestration_manager => ems)
  end

  it "provides all os types and default to unknown" do
    ws = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template.id}", user)
    ws.root["values"].should include(os_list)
    ws.root["default_value"].should == 'unknown'
  end

  it "provides all os types and auto selects the type based on the user selection of an image" do
    ws = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template.id}&dialog_param_userImageName=uid1", user)
    ws.root["values"].should include(os_list)
    ws.root["default_value"].should == 'windows'
  end
end
