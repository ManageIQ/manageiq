RSpec.describe AutomationTask do
  before do
    allow(MiqServer).to receive(:my_zone).and_return("default")
    @admin       = FactoryBot.create(:user_admin)

    @ae_instance = "IIII"
    @ae_message  = "MMMM"
    @ae_var1     = "vvvv"
    @ae_var2     = "wwww"
    @ae_var3     = "xxxx"

    @attrs   = {:var1 => @ae_var1, :var2 => @ae_var2, :var3 => @ae_var3, :userid => @admin.userid}
    @options = {:attrs => @attrs, :instance => @instance, :message => @message, :user_id => @admin.id, :delivered_on => Time.now.utc.to_s}
    @at = FactoryBot.create(:automation_task, :state => 'pending', :status => 'Ok', :userid => @admin.userid, :options => @options)
    @ar = FactoryBot.create(:automation_request)
    @ar.automation_tasks << @at
    @ar.save!
  end

  it "#execute" do
    options = {
      :user_id      => @admin.id,
      :miq_group_id => @admin.current_group.id,
      :tenant_id    => @admin.current_tenant.id
    }
    expect(MiqAeEngine).to receive(:deliver).with(hash_including(options)).once
    @at.execute
    expect(@ar.reload.message).to eq("#{AutomationRequest::TASK_DESCRIPTION} initiated")
  end
end
