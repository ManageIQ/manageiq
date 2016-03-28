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

  def ssl_options(*_args)
    {}
  end

  def auth_options(*_args)
    {}
  end
end

class MockImageInspectorClient
  def initialize(for_id)
    @for_id = for_id
  end

  def fetch_metadata(*_args)
    OpenStruct.new('Id' => @for_id)
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
      job = @ems.scan_job_create(image.class.name, image.id)

      expect(MiqQueue.exists?(:method_name => 'signal',
                              :class_name  => 'Job',
                              :instance_id => job.id,
                              :role        => 'smartstate')).to be true
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

      @job = @image.scan
      allow(MiqQueue).to receive(:put_unless_exists) do |args|
        @job.signal(*args[:args])
      end
    end

    it 'should report success' do
      VCR.use_cassette(described_class.name.underscore, :record => :none) do # needed for health check
        expect(@job.state).to eq 'waiting_to_start'
        @job.signal(:start)
        expect(@job.state).to eq 'finished'
        expect(@job.status).to eq 'ok'
      end
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
      CODE = 0
      CLIENT_MESSAGE = 'error'.freeze
      before(:each) do
        allow_any_instance_of(MockKubeClient).to receive(:create_pod) do |_instance, *_args|
          raise KubeException.new(CODE, CLIENT_MESSAGE, nil)
        end
      end

      it 'should report the error' do
        @job.signal(:start)
        expect(@job.state).to eq 'finished'
        expect(@job.status).to eq 'error'
        expect(@job.message).to eq "pod creation for management-infra/manageiq-img-scan-3629a651e6c1" \
                               " failed: HTTP status code #{CODE}, #{CLIENT_MESSAGE}"
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
        expect(@job.message).to eq "cannont analyze non-docker images"
      end
    end

    context 'when the image tag points to a different image' do
      before(:each) do
        MODIFIED_IMAGE_ID = '0d071bb732e1e3eb1e01629600c9b6c23f2b26b863b5321335f564c8f018c452'.freeze
        allow_any_instance_of(described_class).to receive_messages(
          :image_inspector_client => MockImageInspectorClient.new(MODIFIED_IMAGE_ID))
      end

      it 'should report the error' do
        VCR.use_cassette(described_class.name.underscore, :record => :none) do # needed for health check
          @job.signal(:start)
          expect(@job.state).to eq 'finished'
          expect(@job.status).to eq 'error'
          expect(@job.message).to eq "cannot analyze image #{IMAGE_NAME} with id #{IMAGE_ID[0..11]}:"\
                                     " detected id was #{MODIFIED_IMAGE_ID[0..11]}"
        end
      end
    end
  end
end
