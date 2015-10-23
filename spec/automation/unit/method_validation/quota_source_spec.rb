require "spec_helper"
include QuotaHelper

def run_automate_method(provision_request)
  attrs = []
  attrs << "MiqProvisionRequest::miq_provision_request=#{@miq_provision_request.id}&" \
         "MiqRequest::miq_request=#{@miq_provision_request.id}" if provision_request
  MiqAeEngine.instantiate("/ManageIQ/system/request/Call_Instance?namespace=System/CommonMethods&" \
                          "class=QuotaMethods&instance=source&#{attrs.join('&')}", @user)
end

describe "Quota Validation" do
  before(:each) do
    setup_model
  end

  it "source" do
    ws = run_automate_method(@miq_provision_request)
    root = ws.root
    quota_source = root['quota_source']
    expect(root['quota_source']).to be_kind_of(MiqAeMethodService::MiqAeServiceMiqGroup)
    expect(quota_source["guid"]).to eq(@user.current_group.guid)
    expect(root['ae_result']).to be_nil
  end
end
