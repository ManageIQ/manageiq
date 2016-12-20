require 'MiqContainerGroup/MiqContainerGroup'

class MockKubeClient
  def create_pod(*_args)
    nil
  end

  def proxy_url(*_args)
    'http://test.com'
  end

  def headers(*_args)
    []
  end

  def get_pod(*_args)
    RecursiveOpenStruct.new(
      :metadata => {
        :annotations => {
          'manageiq.org/jobid' => '5'
        }
      }
    )
  end

  def get_service_account(*_args)
    RecursiveOpenStruct.new(
      :metadata         => {
        :name => 'inspector-admin'
      },
      :imagePullSecrets => [
        OpenStruct.new(:name => 'inspector-admin-dockercfg-blabla')
      ]
    )
  end

  def ssl_options(*_args)
    {}
  end

  def auth_options(*_args)
    {}
  end
end

class MockImageInspectorClient
  def initialize(for_id, repo_digest = nil)
    @for_id = for_id
    @repo_digest = repo_digest
  end

  def fetch_metadata(*_args)
    if @repo_digest
      OpenStruct.new('Id' => @for_id, 'RepoDigests' => ["123456677899987765543322", @repo_digest])
    else
      OpenStruct.new('Id' => @for_id)
    end
  end

  def fetch_oscap_arf
    File.read(
      File.expand_path(File.join(File.dirname(__FILE__), "ssg-fedora-ds-arf.xml"))
    ).encode("UTF-8")
  end
end

describe ManageIQ::Providers::Kubernetes::ContainerManager::Scanning::Job do
  context "SmartState Analysis Methods" do
    before(:each) do
      EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryGirl.create(:ems_kubernetes, :hostname => 'hostname')
    end

    it "#initialize" do
      image = FactoryGirl.create(:container_image, :ext_management_system => @ems)
      job = @ems.raw_scan_job_create(image)
      expect(job).to have_attributes(
        :dispatch_status => "pending",
        :state           => "waiting_to_start",
        :status          => "ok",
        :message         => "process initiated",
        :target_class    => "ContainerImage"
      )
    end
  end

  context "A single Container Scan Job," do
    IMAGE_ID = '3629a651e6c11d7435937bdf41da11cf87863c03f2587fa788cf5cbfe8a11b9a'.freeze
    IMAGE_NAME = 'test'.freeze
    before(:each) do
      @server = EvmSpecHelper.local_miq_server

      allow_any_instance_of(described_class).to receive_messages(:kubernetes_client => MockKubeClient.new)
      allow_any_instance_of(described_class).to receive_messages(
        :image_inspector_client => MockImageInspectorClient.new(IMAGE_ID))

      @ems = FactoryGirl.create(
        :ems_kubernetes, :hostname => "test.com", :zone => @server.zone, :port => 8443,
        :authentications => [AuthToken.new(:name => "test", :type => 'AuthToken', :auth_key => "a secret")]
      )

      @image = FactoryGirl.create(
        :container_image, :ext_management_system => @ems, :name => IMAGE_NAME,
        :image_ref => "docker://#{IMAGE_ID}"
      )

      allow_any_instance_of(@image.class).to receive(:scan_metadata) do |_instance, _args|
        @job.signal(:data, '<summary><scanmetadata></scanmetadata></summary>')
      end

      allow_any_instance_of(@image.class).to receive(:sync_metadata) do |_instance, _args|
        @job.signal(:data, '<summary><syncmetadata></syncmetadata></summary>')
      end

      @job = @ems.raw_scan_job_create(@image)
      allow(MiqQueue).to receive(:put_unless_exists) do |args|
        @job.signal(*args[:args])
      end
    end

    context "completes successfully" do
      before(:each) do
        allow_any_instance_of(described_class).to receive_messages(:collect_compliance_data) unless OpenscapResult.openscap_available?

        VCR.use_cassette(described_class.name.underscore, :record => :none) do # needed for health check
          expect(@job.state).to eq 'waiting_to_start'
          @job.signal(:start)
        end
      end

      it 'should report success' do
        expect(@job.state).to eq 'finished'
        expect(@job.status).to eq 'ok'
      end

      it 'should persist openscap data' do
        skip unless OpenscapResult.openscap_available?

        expect(@image.openscap_result).to be
        expect(@image.openscap_result.binary_blob.md5).to eq('d1f1857281573cd777b31d76e8529dc9')
        expect(@image.openscap_result.openscap_rule_results.count).to eq(213)
      end
    end

    it 'should add correct environment variables' do
      att_name = 'http_proxy'
      my_value = "MY_TEST_VALUE"
      @ems.custom_attributes.create(:section => described_class::ATTRIBUTE_SECTION,
                                    :name    => att_name,
                                    :value   => my_value)
      allow_any_instance_of(described_class).to receive_messages(:kubernetes_client => MockKubeClient.new)
      kc = @job.kubernetes_client
      secret_name = kc.get_service_account[:imagePullSecrets][0][:name]
      pod = @job.send(:pod_definition, secret_name)
      expect(pod[:spec][:containers][0][:env][0][:name]).to eq(att_name.upcase)
      expect(pod[:spec][:containers][0][:env][0][:value]).to eq(my_value)
    end

    it 'should send correct dockercfg secrets' do
      allow_any_instance_of(described_class).to receive_messages(:kubernetes_client => MockKubeClient.new)
      kc = @job.kubernetes_client
      secret_name = kc.get_service_account[:imagePullSecrets][0][:name]
      pod = @job.send(:pod_definition, secret_name)
      expect(pod[:spec][:containers][0][:command]).to include(
        "--dockercfg=" + described_class::INSPECTOR_ADMIN_SECRET_PATH + secret_name + "/.dockercfg")
      expect(pod[:spec][:containers][0][:volumeMounts]).to include(
        Kubeclient::Resource.new(
          :name      => "inspector-admin-secret",
          :mountPath => described_class::INSPECTOR_ADMIN_SECRET_PATH + secret_name,
          :readOnly  => true))
      expect(pod[:spec][:volumes]).to include(
        Kubeclient::Resource.new(
          :name   => "inspector-admin-secret",
          :secret => {:secretName => secret_name}))
    end

    context 'when the job is called with a non existing image' do
      before(:each) do
        @image.delete
      end

      it 'should report the error' do
        @job.signal(:start)
        expect(@job.state).to eq 'finished'
        expect(@job.status).to eq 'error'
        expect(@job.message).to eq "no image found"
      end
    end

    context 'when create pod throws exception' do
      before(:each) do
        allow_any_instance_of(MockKubeClient).to receive(:create_pod) do |_instance, *_args|
          raise KubeException.new(0, 'error', nil)
        end
      end

      it 'should report the error' do
        @job.signal(:start)
        expect(@job.state).to eq 'finished'
        expect(@job.status).to eq 'error'
        expect(@job.message).to eq "pod creation for [management-infra/manageiq-img-scan-#{@job.guid[0..4]}] failed"
      end
    end

    context 'when getting the service account throws exception' do
      before(:each) do
        allow_any_instance_of(MockKubeClient).to receive(:get_service_account) do |_instance, *_args|
          raise KubeException.new(0, 'error', nil)
        end
      end

      it 'should report the error' do
        @job.signal(:start)
        expect(@job.state).to eq 'finished'
        expect(@job.status).to eq 'error'
        expect(@job.message).to eq "getting inspector-admin secret failed"
      end
    end

    context 'when given a non docker image' do
      before(:each) do
        allow_any_instance_of(@image.class).to receive(:image_ref) do
          'rocket://3629a651e6c11d7435937bdf41da11cf87863c03f2587fa788cf5cbfe8a11b9a'
        end
      end

      it 'should fail' do
        @job.signal(:start)
        expect(@job.state).to eq 'finished'
        expect(@job.status).to eq 'error'
        expect(@job.message).to eq "cannot analyze non docker images"
      end
    end

    context 'when the image tag points to a different image' do
      MODIFIED_IMAGE_ID = '0d071bb732e1e3eb1e01629600c9b6c23f2b26b863b5321335f564c8f018c452'.freeze
      before(:each) do
        allow_any_instance_of(described_class).to receive_messages(
          :image_inspector_client => MockImageInspectorClient.new(MODIFIED_IMAGE_ID))
      end

      it 'should check for repo_digests' do
        allow_any_instance_of(described_class).to receive_messages(:collect_compliance_data) unless OpenscapResult.openscap_available?
        allow_any_instance_of(described_class).to receive_messages(
          :image_inspector_client => MockImageInspectorClient.new(MODIFIED_IMAGE_ID, IMAGE_ID))
        VCR.use_cassette(described_class.name.underscore, :record => :none) do # needed for health check
          @job.signal(:start)
          expect(@job.state).to eq 'finished'
          expect(@job.status).to eq 'ok'
        end
      end

      it 'should report the error' do
        VCR.use_cassette(described_class.name.underscore, :record => :none) do # needed for health check
          @job.signal(:start)
          expect(@job.state).to eq 'finished'
          expect(@job.status).to eq 'error'
          expect(@job.message).to eq "cannot analyze image #{IMAGE_NAME} with id #{IMAGE_ID[0..11]}:"\
                                     " detected ids were #{MODIFIED_IMAGE_ID[0..11]}"
        end
      end
    end

    context '#verify_scanned_image_id' do
      DOCKER_DAEMON_IMAGE_ID = '123456'.freeze

      before(:each) do
        @job.options[:docker_image_id] = IMAGE_ID
        @job.options[:image_full_name] = IMAGE_NAME
      end

      it 'should report the error when the scanned Id is different than the Image Id' do
        msg = @job.verify_scanned_image_id(OpenStruct.new(:Id => DOCKER_DAEMON_IMAGE_ID))
        expect(msg).to eq "cannot analyze image #{IMAGE_NAME} with id #{IMAGE_ID[0..11]}:"\
                          " detected ids were #{DOCKER_DAEMON_IMAGE_ID[0..11]}"
      end

      context 'checking RepoDigests' do
        DOCKER_IMAGE_ID = "image_name@sha256:digest654321abcdef".freeze
        OTHER_REPOD = "OTHER_REPOD".freeze

        before(:each) do
          @job.options[:docker_image_id] = DOCKER_IMAGE_ID
          @job.options[:image_full_name] = "docker-pullable://" + DOCKER_IMAGE_ID
        end

        it 'checks that the Id is in RepoDigests' do
          msg = @job.verify_scanned_image_id(OpenStruct.new(:Id          => DOCKER_DAEMON_IMAGE_ID,
                                                            :RepoDigests => [DOCKER_IMAGE_ID],
                                                           ))
          expect(msg).to eq nil
        end

        it 'checks all the RepoDigests' do
          msg = @job.verify_scanned_image_id(OpenStruct.new(:Id          => DOCKER_DAEMON_IMAGE_ID,
                                                            :RepoDigests => [OTHER_REPOD, DOCKER_IMAGE_ID],
                                                           ))
          expect(msg).to eq nil
        end

        it 'compares RepoDigests hash part only' do
          # in case the image didn't have a defined registry
          msg = @job.verify_scanned_image_id(OpenStruct.new(:Id          => DOCKER_DAEMON_IMAGE_ID,
                                                            :RepoDigests => ["reponame/" + DOCKER_IMAGE_ID],
                                                           ))
          expect(msg).to eq nil
        end

        it 'reports all attempted IDs' do
          # in case the image didn't have a defined registry
          msg = @job.verify_scanned_image_id(OpenStruct.new(:Id          => DOCKER_DAEMON_IMAGE_ID,
                                                            :RepoDigests => [OTHER_REPOD],
                                                           ))
          expect(msg).to eq "cannot analyze image docker-pullable://#{DOCKER_IMAGE_ID} with id #{DOCKER_IMAGE_ID[0..11]}:"\
                            " detected ids were #{DOCKER_DAEMON_IMAGE_ID[0..11]}, #{OTHER_REPOD}"
        end
      end
    end
  end
end
