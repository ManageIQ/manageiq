require "spec_helper"
include QuotaHelper

def run_automate_method(provision_request)
  attrs = []
  attrs << "MiqProvisionRequest::miq_provision_request=#{provision_request.id}&" \
           "MiqRequest::miq_request=#{provision_request.id}&" \
           "Tenant::quota_source=#{@tenant.id}&max_cpu=3&max_vms=2&quota_source_type=tenant" if provision_request
  MiqAeEngine.instantiate("/ManageIQ/system/request/Call_instance?namespace=System/CommonMethods&" \
                          "class=QuotaMethods&instance=limits&#{attrs.join('&')}", @user)
end

describe "Quota Validation" do
  before do
    setup_model
    setup_tags
  end

  it "limits" do
    ws = run_automate_method(@miq_provision_request)
    root = ws.root
    expect(root['quota_source']).to be_kind_of(MiqAeMethodService::MiqAeServiceTenant)
    expect(root['ae_result']).to be_nil
    expect(root['quota_limit_max'][:storage]).to eq(4096)
    expect(root['quota_limit_max'][:cpu]).to eq(2)
    expect(root['quota_limit_max'][:vms]).to eq(4)
    expect(root['quota_limit_max'][:memory]).to eq(2048)
  end
end
