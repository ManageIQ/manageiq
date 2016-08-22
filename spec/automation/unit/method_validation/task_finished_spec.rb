describe "task_finished_status" do
  include Spec::Support::AutomationHelper

  def build_resolve_path
    instance  = "/System/Request/Call_Method"
    namespace = "namespace=/ManageIQ/System/CommonMethods"
    klass     = "class=StateMachineMethods"
    method    = "method=task_finished"
    "#{instance}?#{namespace}&#{klass}&#{method}"
  end

  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:ws) { MiqAeEngine.instantiate("#{build_resolve_path}&#{@args}", user) }
  let(:miq_server) { EvmSpecHelper.local_miq_server }
  let(:ems) { FactoryGirl.create(:ems_vmware_with_authentication) }
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

  it "miq_provision method succeeds" do
    @args = "status=fred&ae_result=ok&MiqProvision::miq_provision=#{provision.id}&" \
            "MiqServer::miq_server=#{miq_server.id}&vmdb_object_type=miq_provision&" \
            "object=miq_provision&message=not used"
    add_call_method
    ws
    expect(provision.reload.status).to eq('Ok')
    expect(provision.state).to eq('finished')
    msg = "[#{miq_server.name}] VM [] Provisioned Successfully"
    expect(miq_provision_request.reload.message).to eq(msg)
  end

  it "task_finished method input message" do
    @args = "status=fred&ae_result=ok&MiqProvision::fred=#{provision.id}&" \
            "MiqServer::miq_server=#{miq_server.id}&vmdb_object_type=fred&" \
            "object=miq_provision&message=finished message here"
    add_call_method
    ws
    msg = "[#{miq_server.name}] finished message here"
    expect(miq_provision_request.reload.message).to eq(msg)
  end
end
