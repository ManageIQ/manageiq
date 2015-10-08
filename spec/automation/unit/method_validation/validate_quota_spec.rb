require “spec_helper”
def run_automate_method(provision_request)
  @quota_used = YAML.dump(:storage => 32768, :vms => 2, :cpu => 2, :memory => 4096)
  @quota_requested = YAML.dump(:storage => 10240, :vms => 1, :cpu => 1, :memory => 1024)
  attrs = []
  attrs << "MiqProvisionRequest::miq_provision_request=#{@miq_provision_request.id}&” \
           "MiqRequest::miq_request=#{@miq_provision_request.id}&” \
           "quota_limit_max_yaml=#{@quota_limit_max}&” \
           "quota_limit_warn_yaml=#{@quota_limit_warn}&” \
           "quota_used_yaml=#{@quota_used}&” \
           "MiqGroup::quota_source=#{@vm1.miq_group.id}&” \
           "quota_requested_yaml=#{@quota_requested}" if provision_request
  ws = MiqAeEngine.instantiate("/ManageIQ/system/request/Call_Instance?namespace=System/CommonMethods&” \
                               "class=QuotaMethods&instance=validate&#{attrs.join('&')}”)
  ws
end

describe "Quota Validation” do
  before(:each) do
    @user = FactoryGirl.create(:user_miq_request_approver)
    @vm_template = FactoryGirl.create(:template_vmware, :name => “template1”)
    @vm1 = FactoryGirl.create(:vm_vmware)
    @vm1.miq_group = @user.current_group
    @miq_provision_request = FactoryGirl.create(:miq_provision_request,
                                                :userid => @user.userid,
                                                :src_vm_id => @vm_template.id)
    @miq_request = @miq_provision_request.create_request
    @miq_request.save!
  end

  context "validate vcpus quota limit, using number of cpus” do
    it "no quota limits set” do
      @quota_limit_max = YAML.dump(:storage => 0, :vms => 0, :cpu => 0, :memory => 0)
      @quota_limit_warn = YAML.dump(:storage => 0, :vms => 0, :cpu => 0, :memory => 0)
      ws = run_automate_method(@miq_provision_request)
      ws.root['ae_result'].should == ‘ok’
    end
  end

  context "validate max limits” do
    it "failure max memory” do
      @quota_limit_max = YAML.dump(:storage => 0, :vms => 0, :cpu => 0, :memory => 4096)
      @quota_limit_warn = YAML.dump(:storage => 0, :vms => 0, :cpu => 0, :memory => 0)
      err_msg = "Request denied due to the following quota limits:” \
                " (memory - Used: 4096 plus requested: 1024 exceeds quota limit: 4096) “
      ws = run_automate_method(@miq_provision_request)
      expect(ws.root['ae_result']).to eql(‘error’)
      @miq_request.reload
      expect(@miq_request.options[:quota_max_exceeded]).to eql(err_msg)
    end

    it "failure warn memory” do
      @quota_limit_warn = YAML.dump(:storage => 0, :vms => 0, :cpu => 0, :memory => 4096)
      @quota_limit_max = YAML.dump(:storage => 0, :vms => 0, :cpu => 0, :memory => 0)
      err_msg = "Request warning due to the following quota thresholds:” \
                " (memory - Used: 4096 plus requested: 1024 exceeds quota limit: 4096) “
      ws = run_automate_method(@miq_provision_request)
      expect(ws.root['ae_result']).to eql(‘ok’)
      @miq_request.reload
      expect(@miq_request.options[:quota_warn_exceeded]).to eql(err_msg)
    end

    it "failure max vms” do
      @quota_limit_max = YAML.dump(:storage => 0, :vms => 2, :cpu => 0, :memory => 0)
      @quota_limit_warn = YAML.dump(:storage => 0, :vms => 0, :cpu => 0, :memory => 0)
      err_msg = "Request denied due to the following quota limits:” \
                " (vms - Used: 2 plus requested: 1 exceeds quota limit: 2) “
      ws = run_automate_method(@miq_provision_request)
      expect(ws.root['ae_result']).to eql(‘error’)
      @miq_request.reload
      expect(@miq_request.options[:quota_max_exceeded]).to eql(err_msg)
    end

    it "failure warn vms” do
      @quota_limit_warn = YAML.dump(:storage => 0, :vms => 1, :cpu => 0, :memory => 0)
      @quota_limit_max = YAML.dump(:storage => 0, :vms => 0, :cpu => 0, :memory => 0)
      err_msg = "Request warning due to the following quota thresholds:” \
                " (vms - Used: 2 plus requested: 1 exceeds quota limit: 1) “
      ws = run_automate_method(@miq_provision_request)
      expect(ws.root['ae_result']).to eql(‘ok’)
      @miq_request.reload
      expect(@miq_request.options[:quota_warn_exceeded]).to eql(err_msg)
    end

    it "failure max cpu” do
      @quota_limit_max = YAML.dump(:storage => 0, :vms => 0, :cpu => 2, :memory => 0)
      @quota_limit_warn = YAML.dump(:storage => 0, :vms => 0, :cpu => 0, :memory => 0)
      err_msg = "Request denied due to the following quota limits:” \
                " (cpu - Used: 2 plus requested: 1 exceeds quota limit: 2) “
      ws = run_automate_method(@miq_provision_request)
      expect(ws.root['ae_result']).to eql(‘error’)
      @miq_request.reload
      expect(@miq_request.options[:quota_max_exceeded]).to eql(err_msg)
    end

    it "failure warn cpu” do
      @quota_limit_warn = YAML.dump(:storage => 0, :vms => 0, :cpu => 1, :memory => 0)
      @quota_limit_max = YAML.dump(:storage => 0, :vms => 0, :cpu => 0, :memory => 0)
      err_msg = "Request warning due to the following quota thresholds:” \
                " (cpu - Used: 2 plus requested: 1 exceeds quota limit: 1) “
      ws = run_automate_method(@miq_provision_request)
      expect(ws.root['ae_result']).to eql(‘ok’)
      @miq_request.reload
      expect(@miq_request.options[:quota_warn_exceeded]).to eql(err_msg)
    end

    it "failure max storage” do
      @quota_limit_max = YAML.dump(:storage => 20480, :vms => 0, :cpu => 0, :memory => 0)
      @quota_limit_warn = YAML.dump(:storage => 0, :vms => 0, :cpu => 0, :memory => 0)
      err_msg = "Request denied due to the following quota limits:” \
                " (storage - Used: 32768 plus requested: 10240 exceeds quota limit: 20480) “
      ws = run_automate_method(@miq_provision_request)
      expect(ws.root['ae_result']).to eql(‘error’)
      @miq_request.reload
      expect(@miq_request.options[:quota_max_exceeded]).to eql(err_msg)
    end

    it "failure warn storage” do
      @quota_limit_warn = YAML.dump(:storage => 10240, :vms => 0, :cpu => 0, :memory => 0)
      @quota_limit_max = YAML.dump(:storage => 0, :vms => 0, :cpu => 0, :memory => 0)
      err_msg = "Request warning due to the following quota thresholds:” \
      " (storage - Used: 32768 plus requested: 10240 exceeds quota limit: 10240) “
      ws = run_automate_method(@miq_provision_request)
      expect(ws.root['ae_result']).to eql(‘ok’)
      @miq_request.reload
      expect(@miq_request.options[:quota_warn_exceeded]).to eql(err_msg)
    end
  end
end
