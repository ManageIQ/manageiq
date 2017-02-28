require 'MiqContainerGroup/MiqContainerGroup'

describe ManageIQ::Providers::Kubernetes::ContainerManager do
  it ".ems_type" do
    expect(described_class.ems_type).to eq('kubernetes')
  end

  it ".raw_api_endpoint (ipv6)" do
    expect(described_class.raw_api_endpoint("::1", 123).to_s).to eq "https://[::1]:123"
  end

  context "#verify_ssl_mode" do
    let(:ems) { FactoryGirl.build(:ems_kubernetes) }

    it "is secure without endpoint" do
      expect(ems.verify_ssl_mode(nil)).to eq(OpenSSL::SSL::VERIFY_PEER)
    end

    it "is secure for old providers without security_protocol" do
      endpoint = Endpoint.new(:verify_ssl => nil)
      expect(ems.verify_ssl_mode(endpoint)).to eq(OpenSSL::SSL::VERIFY_PEER)
      # In practice both API and UI used set verify_ssl == VERIFY_PEER.
      endpoint = Endpoint.new(:verify_ssl => OpenSSL::SSL::VERIFY_PEER)
      expect(ems.verify_ssl_mode(endpoint)).to eq(OpenSSL::SSL::VERIFY_PEER)
    end

    it "respects explicit verify_ssl == 0 in absence of security_protocol" do
      endpoint = Endpoint.new(:verify_ssl => OpenSSL::SSL::VERIFY_NONE)
      expect(endpoint.verify_ssl?).to be_falsey
      expect(ems.verify_ssl_mode(endpoint)).to eq(OpenSSL::SSL::VERIFY_NONE)
    end

    it "uses security_protocol when given" do
      # security_protocol should win over opposite verify_ssl
      endpoint = Endpoint.new(:security_protocol => 'ssl-with-validation',
                              :verify_ssl        => OpenSSL::SSL::VERIFY_NONE)
      expect(ems.verify_ssl_mode(endpoint)).to eq(OpenSSL::SSL::VERIFY_PEER)

      # The UI doesn't currently use 'ssl' but it's plausible someone
      # would send this via API.  Generally unexpect values should mean secure.
      endpoint = Endpoint.new(:security_protocol => 'ssl',
                              :verify_ssl        => OpenSSL::SSL::VERIFY_NONE)
      expect(ems.verify_ssl_mode(endpoint)).to eq(OpenSSL::SSL::VERIFY_PEER)

      endpoint = Endpoint.new(:security_protocol => 'ssl-with-validation-custom-ca',
                              :verify_ssl        => OpenSSL::SSL::VERIFY_NONE)
      expect(ems.verify_ssl_mode(endpoint)).to eq(OpenSSL::SSL::VERIFY_PEER)

      endpoint = Endpoint.new(:security_protocol => 'ssl-without-validation',
                              :verify_ssl        => OpenSSL::SSL::VERIFY_PEER)
      expect(ems.verify_ssl_mode(endpoint)).to eq(OpenSSL::SSL::VERIFY_NONE)
    end
  end

  context "SmartState Analysis Methods" do
    before(:each) do
      EvmSpecHelper.local_miq_server(:zone => Zone.seed)
      @ems = FactoryGirl.create(
        :ems_kubernetes,
        :hostname        => 'hostname',
        :authentications => [
          FactoryGirl.build(:authentication, :authtype => 'bearer', :auth_key => 'valid-token'),
          FactoryGirl.build(:authentication, :authtype => 'hawkular')
        ]
      )
      allow(@ems).to receive_message_chain(:connect, :proxy_url => "Hello")
      allow(@ems).to receive_message_chain(:connect, :headers   => { "Authorization" => "Bearer valid-token" })
    end

    it "checks for the right credential fields" do
      expect(@ems.required_credential_fields(:bearer)).to eq([:auth_key])
    end

    it "checks for missing_credentials" do
      expect(@ems.missing_credentials?(:bearer)).to be_falsey
      expect(@ems.missing_credentials?(:hawkular)).to be_truthy
    end

    it ".scan_entity_create" do
      entity = @ems.scan_entity_create(
        :pod_namespace => 'default',
        :pod_name      => 'name',
        :pod_port      => 8080,
        :guest_os      => 'GuestOS'
      )

      expect(entity).to be_kind_of(MiqContainerGroup)
      expect(entity.http_options).to include(:use_ssl => true, :verify_mode => @ems.verify_ssl_mode)
      expect(entity.headers).to eq("Authorization" => "Bearer valid-token")
      expect(entity.guest_os).to eq('GuestOS')
    end

    it ".scan_job_create" do
      image = FactoryGirl.create(:container_image, :ext_management_system => @ems)
      job = @ems.raw_scan_job_create(image)

      expect(job.state).to eq("waiting_to_start")
      expect(job.status).to eq("ok")
      expect(job.target_class).to eq(image.class.name)
      expect(job.target_id).to eq(image.id)
      expect(job.type).to eq(ManageIQ::Providers::Kubernetes::ContainerManager::Scanning::Job.name)
      expect(job.zone).to eq("default")
    end
  end

  context "kubeclient" do
    let(:hostname) { "hostname" }
    let(:port) { "1234" }
    let(:options) { { :ssl_options => { :bearer_token => "4321" } } }
    it ". raw_connect" do
      allow(VMDB::Util).to receive(:http_proxy_uri).and_return(URI::HTTP.build(:host => "some"))
      require 'kubeclient'
      expect(Kubeclient::Client).to receive(:new).with(
        instance_of(URI::HTTPS), 'v1',
        hash_including(:http_proxy_uri => VMDB::Util.http_proxy_uri)
      )
      described_class.raw_connect(hostname, port, options)
    end
  end
end
