describe "Quota Validation" do
  include Spec::Support::QuotaHelper

  def run_automate_method(provision_request, quota_source)
    source = case quota_source
             when 'tenant'
               "Tenant::quota_source=#{@tenant.id}&quota_source_type=tenant"
             when 'group'
               "MiqGroup::quota_source=#{@miq_group.id}&quota_source_type=group"
             end

    attrs = []
    attrs << "MiqProvisionRequest::miq_provision_request=#{provision_request.id}&" \
             "MiqRequest::miq_request=#{provision_request.id}&max_cpu=3&max_vms=2&#{source}" if provision_request
    MiqAeEngine.instantiate("/ManageIQ/system/request/Call_instance?namespace=System/CommonMethods&" \
                            "class=QuotaMethods&instance=limits&#{attrs.join('&')}", @user)
  end

  before do
    setup_model
    setup_tags
  end

  it "limits, using tenant as quota source" do
    ws = run_automate_method(@miq_provision_request, 'tenant')
    root = ws.root
    expect(root['quota_source']).to be_kind_of(MiqAeMethodService::MiqAeServiceTenant)
    expect(root['quota_limit_max'][:storage]).to eq(4096)
    expect(root['quota_limit_max'][:cpu]).to eq(2)
    expect(root['quota_limit_max'][:vms]).to eq(4)
    expect(root['quota_limit_max'][:memory]).to eq(2048)
  end

  it "limits, using group as quota source" do
    ws = run_automate_method(@miq_provision_request, 'group')
    root = ws.root
    expect(root['quota_source']).to be_kind_of(MiqAeMethodService::MiqAeServiceMiqGroup)
    expect(root['quota_limit_max'][:storage]).to eq(2.terabytes)
    expect(root['quota_limit_max'][:cpu]).to eq(4)
    expect(root['quota_limit_max'][:vms]).to eq(4)
    expect(root['quota_limit_max'][:memory]).to eq(2.gigabytes)
  end
end
