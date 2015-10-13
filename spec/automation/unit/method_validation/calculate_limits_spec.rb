require "spec_helper"
include QuotaHelper

def run_automate_method(provision_request)
  attrs = []
  attrs << "MiqProvisionRequest::miq_provision_request=#{@miq_provision_request.id}&" \
           "MiqRequest::miq_request=#{@miq_provision_request.id}&" \
           "MiqGroup::quota_source=#{@miq_group.id}&max_cpu=3&max_vms=2" if provision_request
  ws = MiqAeEngine.instantiate("/ManageIQ/system/request/Call_instance?namespace=System/CommonMethods&" \
                               "class=QuotaMethods&instance=limits&#{attrs.join('&')}")
  ws
end

describe "Quota Validation" do
  before(:each) do
    setup_model
    setup_tags
  end

  it "limits" do
    ws = run_automate_method(@miq_provision_request)
    root = ws.root
    quota_source = root['quota_source']
    expect(root['quota_source']).to be_kind_of(MiqAeMethodService::MiqAeServiceMiqGroup)
    expect(quota_source["guid"]).to eq(@user.current_group.guid)
    expect(root['ae_result']).to be_nil
    expect(root['quota_limit_max'][:storage]).to eq(2048)
    expect(root['quota_limit_max'][:cpu]).to eq(4)
    expect(root['quota_limit_max'][:vms]).to eq(4)
    expect(root['quota_limit_max'][:memory]).to eq(2048)
  end
end
