include AutomationSpecHelper

describe "update_provision_status" do
  let(:user)      { FactoryGirl.create(:user_with_group) }

  context "with a provision request object" do
    let(:ems)   { FactoryGirl.create(:ems_vmware_with_authentication) }
    let(:vm_template) { FactoryGirl.create(:template_vmware, :ext_management_system => ems) }
    let(:options) { {:src_vm_id => [vm_template.id, vm_template.name], :pass => 1} }
    let(:miq_provision_request) do
      FactoryGirl.create(:miq_provision_request,
                         :provision_type => 'template',
                         :state => 'pending', :status => 'Ok',
                         :src_vm_id => vm_template.id,
                         :requester => user)
    end

    let(:provision) do
      FactoryGirl.create(:miq_provision_vmware, :provision_type => 'template',
                         :state => 'pending', :status => 'Ok',
                         :miq_request => miq_provision_request,
                         :options => options, :userid => user.userid)
    end

    let(:ws) { MiqAeEngine.instantiate("/System/Request/Call_Method?namespace=/ManageIQ/Infrastructure/VM/Provisioning/StateMachines&status=fred&class=VMProvision_VM&method=update_provision_status&ae_result=ok&MiqProvision::miq_provision=#{provision.id}", user) }
    it "method succeeds" do
      add_call_method
      ws
      expect(provision.reload.status).to eq('Ok')
    end
  end

  context "without a provision object" do
    let(:ws) { MiqAeEngine.instantiate("/System/Request/Call_Method?namespace=/ManageIQ/Infrastructure/VM/Provisioning/StateMachines&status=fred&class=VMProvision_VM&method=update_provision_status&ae_result=ok", user) }
    it "method fails" do
      add_call_method
      expect(ws.root).to be_nil
    end
  end
end
