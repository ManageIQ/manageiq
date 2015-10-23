require "spec_helper"
include QuotaHelper

def run_automate_method(prov_req)
  attrs = []
  attrs << "MiqProvisionRequest::miq_provision_request=#{@miq_provision_request.id}&" \
           "MiqRequest::miq_request=#{@miq_provision_request.id}&MiqGroup::quota_source=#{@miq_group.id}" if prov_req
  MiqAeEngine.instantiate("/ManageIQ/system/request/Call_Instance?namespace=System/CommonMethods&" \
                          "class=QuotaMethods&instance=requested&#{attrs.join('&')}", @user)
end

describe "Quota Validation" do
  before do
    setup_model
  end

  it "calculate_requested" do
    ws = run_automate_method(@miq_provision_request)
    root = ws.root
    quota_entity = root['quota_source']
    expect(root['quota_source']).to be_kind_of(MiqAeMethodService::MiqAeServiceMiqGroup)
    expect(quota_entity["guid"]).to eq(@user.current_group.guid)
    expect(root['ae_result']).to be_nil
    expect(root['quota_requested'][:storage]).to eq(512)
    expect(root['quota_requested'][:cpu]).to eq(2)
    expect(root['quota_requested'][:vms]).to eq(1)
    expect(root['quota_requested'][:memory]).to eq(1024)
  end
end
