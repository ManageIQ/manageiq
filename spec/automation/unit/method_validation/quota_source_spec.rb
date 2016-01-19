include QuotaHelper

describe "Quota Validation" do
  def run_automate_method(provision_request)
    attrs = []
    attrs << "MiqProvisionRequest::miq_provision_request=#{provision_request.id}&" \
           "MiqRequest::miq_request=#{provision_request.id}" if provision_request
    MiqAeEngine.instantiate("/ManageIQ/system/request/Call_Instance?namespace=System/CommonMethods&" \
                            "class=QuotaMethods&instance=quota_source&#{attrs.join('&')}", @user)
  end

  before do
    setup_model
  end

  it "source" do
    ws = run_automate_method(@miq_provision_request)
    root = ws.root
    expect(root['quota_source']).to be_kind_of(MiqAeMethodService::MiqAeServiceTenant)
  end
end
