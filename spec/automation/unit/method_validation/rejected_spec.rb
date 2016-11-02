describe "Quota rejected Validation" do
  let(:admin) { FactoryGirl.create(:user_with_email_and_group, :name => 'admin', :userid => 'admin') }
  let(:admin_approval) { FactoryGirl.create(:miq_approval, :approver => admin) }
  let(:ws) { MiqAeEngine.instantiate("/System/Request/Call_Method?#{method}&#{args}", admin) }
  let(:method) do
    "namespace=/ManageIQ/System/CommonMethods&class=QuotaStateMachine&method=rejected"
  end
  let(:args) do
    "status=fred&ae_result=error&MiqProvisionRequest::miq_request=#{miq_provision_request.id}&" \
               "MiqServer::miq_server=#{miq_server.id}"
  end

  let(:miq_server) { EvmSpecHelper.local_miq_server }
  let(:ems) { FactoryGirl.create(:ems_vmware_with_authentication) }
  let(:vm_template) { FactoryGirl.create(:template_vmware, :ext_management_system => ems) }
  let(:vm) { FactoryGirl.create(:vm_vmware, :ext_management_system => ems) }
  let(:miq_provision_request) do
    FactoryGirl.create(:miq_provision_request,
                       :provision_type => 'template',
                       :state => 'pending', :status => 'Ok',
                       :src_vm_id => vm_template.id,
                       :requester => admin)
  end

  it "Quota exceeded" do
    type = :automate_user_error
    FactoryGirl.create(:notification_type, :name => type)

    expect(Notification.count).to eq(0)
    miq_provision_request.miq_approvals = [admin_approval]
    miq_provision_request.save!
    add_call_method

    ws
    expect(Notification.find_by(:notification_type_id => NotificationType.find_by_name(type).id)).not_to be_nil
  end
end
