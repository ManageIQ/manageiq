describe "Quota Validation" do
  include Spec::Support::QuotaHelper

  def run_automate_method(prov_req)
    attrs = []
    attrs << "MiqProvisionRequest::miq_provision_request=#{@miq_provision_request.id}&" \
             "MiqRequest::miq_request=#{@miq_provision_request.id}&Tenant::quota_source=#{@tenant.id}" if prov_req
    MiqAeEngine.instantiate("/ManageIQ/system/request/Call_Instance?namespace=System/CommonMethods&" \
                            "class=QuotaMethods&instance=used&#{attrs.join('&')}", @user)
  end

  before do
    setup_model
  end

  it "calculate_used" do
    ws = run_automate_method(@miq_provision_request)
    root = ws.root
    expect(root['quota_source']).to be_kind_of(MiqAeMethodService::MiqAeServiceTenant)
    expect(root['quota_used'][:storage]).to eq(1_000_000)
    expect(root['quota_used'][:cpu]).to eq(0)
    expect(root['quota_used'][:vms]).to eq(2)
    expect(root['quota_used'][:provisioned_storage]).to eq(1_074_741_824)
    expect(root['quota_used'][:memory]).to eq(1_073_741_824)
  end
end
