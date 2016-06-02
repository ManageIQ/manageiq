include QuotaHelper

describe "Quota Validation" do
  def run_automate_method(provision_request)
    @quota_used       = YAML.dump(:storage => 32_768, :vms => 2, :cpu => 2,  :memory => 4096)
    @quota_requested  = YAML.dump(:storage => 10_240, :vms => 1, :cpu => 1,  :memory => 1024)
    attrs = []
    attrs << "MiqProvisionRequest::miq_provision_request=#{@miq_provision_request.id}&" \
             "MiqRequest::miq_request=#{@miq_provision_request.id}&" \
             "quota_limit_max_yaml=#{@quota_limit_max}&" \
             "quota_limit_warn_yaml=#{@quota_limit_warn}&" \
             "quota_used_yaml=#{@quota_used}&" \
             "Tenant::quota_source=#{@tenant.id}&" \
             "quota_requested_yaml=#{@quota_requested}" if provision_request
    MiqAeEngine.instantiate("/ManageIQ/system/request/Call_Instance?namespace=System/CommonMethods&" \
                            "class=QuotaMethods&instance=validate_quota&#{attrs.join('&')}", @user)
  end

  before do
    setup_model
  end

  context "validate vcpus quota limit, using number of cpus" do
    it "no quota limits set" do
      @quota_limit_max  = YAML.dump(:storage => 0, :vms => 0, :cpu => 0, :memory => 0)
      @quota_limit_warn = YAML.dump(:storage => 0, :vms => 0, :cpu => 0, :memory => 0)
      ws = run_automate_method(@miq_provision_request)
      expect(ws.root['ae_result']).to eq('ok')
    end
  end

  context "validate max limits" do
    it "failure max memory" do
      @quota_limit_max = YAML.dump(:storage => 0, :vms => 0, :cpu => 0, :memory => 4096)
      @quota_limit_warn = YAML.dump(:storage => 0, :vms => 0, :cpu => 0, :memory => 0)
      err_msg = "Request exceeds maximum allowed for the following:" \
                " (memory - Used: 4 KB plus requested: 1 KB exceeds quota: 4 KB) "
      ws = run_automate_method(@miq_provision_request)
      expect(ws.root['ae_result']).to eql('error')
      @miq_request.reload
      expect(@miq_request.options[:quota_max_exceeded]).to eql(err_msg)
      expect(@miq_request.message).to eql(err_msg)
    end

    it "failure warn memory" do
      @quota_limit_warn = YAML.dump(:storage => 0, :vms => 0, :cpu => 0, :memory => 4096)
      @quota_limit_max = YAML.dump(:storage => 0, :vms => 0, :cpu => 0, :memory => 0)
      err_msg = "Request exceeds warning limits for the following:" \
                " (memory - Used: 4 KB plus requested: 1 KB exceeds quota: 4 KB) "
      ws = run_automate_method(@miq_provision_request)
      expect(ws.root['ae_result']).to eql('ok')
      @miq_request.reload
      expect(@miq_request.options[:quota_warn_exceeded]).to eql(err_msg)
      expect(@miq_request.message).to eql(err_msg)
    end

    it "failure max vms" do
      @quota_limit_max  = YAML.dump(:storage => 0, :vms => 2, :cpu => 0, :memory => 0)
      @quota_limit_warn = YAML.dump(:storage => 0, :vms => 0, :cpu => 0, :memory => 0)
      err_msg = "Request exceeds maximum allowed for the following:" \
                " (vms - Used: 2 plus requested: 1 exceeds quota: 2) "
      ws = run_automate_method(@miq_provision_request)
      expect(ws.root['ae_result']).to eql('error')
      @miq_request.reload
      expect(@miq_request.options[:quota_max_exceeded]).to eql(err_msg)
      expect(@miq_request.message).to eql(err_msg)
    end

    it "failure warn vms" do
      @quota_limit_warn  = YAML.dump(:storage => 0, :vms => 1, :cpu => 0, :memory => 0)
      @quota_limit_max = YAML.dump(:storage => 0, :vms => 0, :cpu => 0, :memory => 0)
      err_msg = "Request exceeds warning limits for the following:" \
                " (vms - Used: 2 plus requested: 1 exceeds quota: 1) "
      ws = run_automate_method(@miq_provision_request)
      expect(ws.root['ae_result']).to eql('ok')
      @miq_request.reload
      expect(@miq_request.options[:quota_warn_exceeded]).to eql(err_msg)
      expect(@miq_request.message).to eql(err_msg)
    end

    it "failure max cpu" do
      @quota_limit_max  = YAML.dump(:storage => 0, :vms => 0, :cpu => 2, :memory => 0)
      @quota_limit_warn = YAML.dump(:storage => 0, :vms => 0, :cpu => 0, :memory => 0)
      err_msg = "Request exceeds maximum allowed for the following:" \
                " (cpu - Used: 2 plus requested: 1 exceeds quota: 2) "
      ws = run_automate_method(@miq_provision_request)
      expect(ws.root['ae_result']).to eql('error')
      @miq_request.reload
      expect(@miq_request.options[:quota_max_exceeded]).to eql(err_msg)
      expect(@miq_request.message).to eql(err_msg)
    end

    it "failure warn cpu" do
      @quota_limit_warn  = YAML.dump(:storage => 0, :vms => 0, :cpu => 1, :memory => 0)
      @quota_limit_max = YAML.dump(:storage => 0, :vms => 0, :cpu => 0, :memory => 0)
      err_msg = "Request exceeds warning limits for the following:" \
                " (cpu - Used: 2 plus requested: 1 exceeds quota: 1) "
      ws = run_automate_method(@miq_provision_request)
      expect(ws.root['ae_result']).to eql('ok')
      @miq_request.reload
      expect(@miq_request.options[:quota_warn_exceeded]).to eql(err_msg)
      expect(@miq_request.message).to eql(err_msg)
    end

    it "failure max storage" do
      @quota_limit_max  = YAML.dump(:storage => 20_480, :vms => 0, :cpu => 0, :memory => 0)
      @quota_limit_warn = YAML.dump(:storage => 0, :vms => 0, :cpu => 0, :memory => 0)
      err_msg = "Request exceeds maximum allowed for the following:" \
                " (storage - Used: 32 KB plus requested: 10 KB exceeds quota: 20 KB) "
      ws = run_automate_method(@miq_provision_request)
      expect(ws.root['ae_result']).to eql('error')
      @miq_request.reload
      expect(@miq_request.options[:quota_max_exceeded]).to eql(err_msg)
      expect(@miq_request.message).to eql(err_msg)
    end

    it "failure warn storage" do
      @quota_limit_warn  = YAML.dump(:storage => 10_240, :vms => 0, :cpu => 0, :memory => 0)
      @quota_limit_max = YAML.dump(:storage => 0, :vms => 0, :cpu => 0, :memory => 0)
      err_msg = "Request exceeds warning limits for the following:" \
                " (storage - Used: 32 KB plus requested: 10 KB exceeds quota: 10 KB) "
      ws = run_automate_method(@miq_provision_request)
      expect(ws.root['ae_result']).to eql('ok')
      @miq_request.reload
      expect(@miq_request.options[:quota_warn_exceeded]).to eql(err_msg)
      expect(@miq_request.message).to eql(err_msg)
    end
  end
end
