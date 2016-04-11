describe 'vmreconfigure_request_approved method' do
  let(:miq_server) { EvmSpecHelper.local_miq_server }
  let(:request)    { FactoryGirl.create(:vm_reconfigure_request, :requester => user) }
  let(:user)       { FactoryGirl.create(:user_with_email_and_group) }

  it 'sends email' do
    expect(GenericMailer).to receive(:deliver).with(:automation_notification,
                                                    hash_including(:to   => user.email,
                                                                   :from => "evmadmin@example.com"
                                                                  )
                                                   )
    attrs = ["MiqServer::miq_server=#{miq_server.id}"]
    attrs << "MiqRequest::miq_request=#{request.id}"
    MiqAeEngine.instantiate("/Infrastructure/VM/Reconfigure/Email/VmReconfigureRequestApproved?" \
                            "event=vm_reconfigured&#{attrs.join('&')}", user)
  end
end
