include QuotaHelper

describe "Quota Validation" do
  def run_automate_method(prov_req)
    attrs = []
    attrs << "MiqProvisionRequest::miq_provision_request=#{@miq_provision_request.id}&" \
             "MiqRequest::miq_request=#{@miq_provision_request.id}&Tenant::quota_source=#{@tenant.id}" if prov_req
    MiqAeEngine.instantiate("/ManageIQ/system/request/Call_Instance?namespace=System/CommonMethods&" \
                            "class=QuotaMethods&instance=requested&#{attrs.join('&')}", @user)
  end

  it "vmware calculate_requested" do
    setup_model("vmware")
    ws = run_automate_method(@miq_provision_request)
    root = ws.root
    expect(root['quota_source']).to be_kind_of(MiqAeMethodService::MiqAeServiceTenant)
    expect(root['quota_requested'][:storage]).to eq(512.megabytes)
    expect(root['quota_requested'][:cpu]).to eq(4)
    expect(root['quota_requested'][:vms]).to eq(1)
    expect(root['quota_requested'][:memory]).to eq(1.gigabytes)
  end

  it "google calculate_requested" do
    setup_model("google")
    ws = run_automate_method(@miq_provision_request)
    root = ws.root
    expect(root['quota_source']).to be_kind_of(MiqAeMethodService::MiqAeServiceTenant)
    expect(root['quota_requested'][:storage]).to eq(10.gigabytes)
    expect(root['quota_requested'][:cpu]).to eq(4)
    expect(root['quota_requested'][:vms]).to eq(1)
    expect(root['quota_requested'][:memory]).to eq(1024)
  end
end
