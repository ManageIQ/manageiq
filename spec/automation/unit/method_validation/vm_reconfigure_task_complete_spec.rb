describe 'vmreconfiguretask_complete method' do
  let(:ems)        { FactoryGirl.create(:ems_vmware, :tenant => Tenant.root_tenant) }
  let(:miq_server) { EvmSpecHelper.local_miq_server }
  let(:user)       { FactoryGirl.create(:user_with_email_and_group) }
  let(:vm)         { FactoryGirl.create(:vm_vmware, :ems_id => ems.id, :evm_owner => user) }

  it 'sends email' do
    expect(GenericMailer).to receive(:deliver).with(:automation_notification,
                                                    hash_including(:to   => user.email,
                                                                   :from => "evmadmin@example.com"
                                                                  )
                                                   )
    attrs = ["MiqServer::miq_server=#{miq_server.id}"]
    attrs << "VmOrTemplate::vm=#{vm.id}"
    MiqAeEngine.instantiate("/Infrastructure/VM/Reconfigure/Email/VmReconfigureTaskComplete?" \
                            "event=vm_reconfigure&#{attrs.join('&')}", user)
  end
end
