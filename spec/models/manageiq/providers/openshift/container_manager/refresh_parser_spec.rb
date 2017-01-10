require 'recursive-open-struct'

describe ManageIQ::Providers::Openshift::ContainerManager::RefreshParser do
  let(:parser) { described_class.new }

  describe "get_openshift_images" do
    let(:image_name) { "image_name" }
    let(:image_tag) { "my_tag" }
    let(:image_digest) { "sha256:abcdefg" }
    let(:image_registry) { '12.34.56.78' }
    let(:image_registry_port) { 5000 }
    let(:image_ref) do
      ContainerImage::DOCKER_PULLABLE_PREFIX + \
        "#{image_registry}:#{image_registry_port}/#{image_name}@#{image_digest}"
    end
    let(:image_from_openshift) do
      RecursiveOpenStruct.new(
        :metadata             => {
          :name => image_digest
        },
        :dockerImageReference => "#{image_registry}:#{image_registry_port}/#{image_name}@#{image_digest}",
        :dockerImageManifest  => '{"name": "%s", "tag": "%s"}' % [image_name, image_tag],
        :dockerImageMetadata  => {
          :Architecture  => "amd64",
          :Author        => "ManageIQ team",
          :Size          => "123456",
          :DockerVersion => "1.12.1",
          :Config        => {
            :Cmd          => %w(run this program),
            :Entrypoint   => %w(entry1 entry2),
            :ExposedPorts => {"12345/tcp".to_sym => {}},
            :Env          => ["VAR1=VALUE1", "VAR2=VALUE2"],
            :Labels       => {:key1 => "value1", :key2 => "value2"}
          }
        }
      )
    end
    let(:image_without_dockerImage_fields) do
      RecursiveOpenStruct.new(
        :metadata => {
          :name => image_digest
        }
      )
    end

    it "collects data from openshift images correctly" do
      expect(parser.send(:parse_openshift_image,
                         image_from_openshift).except(:registered_on)).to eq(
                           :name                     => image_name,
                           :digest                   => image_digest,
                           :image_ref                => image_ref,
                           :tag                      => image_tag,
                           :container_image_registry => {:name => image_registry,
                                                         :host => image_registry,
                                                         :port => image_registry_port.to_s},
                           :architecture             => "amd64",
                           :author                   => "ManageIQ team",
                           :command                  => %w(run this program),
                           :entrypoint               => %w(entry1 entry2),
                           :docker_version           => "1.12.1",
                           :exposed_ports            => {'tcp' => '12345'},
                           :environment_variables    => {"VAR1" => "VALUE1", "VAR2" => "VALUE2"},
                           :size                     => "123456",
                           :labels                   => [],
                           :docker_labels            => [{:section => "docker_labels",
                                                          :name    => "key1",
                                                          :value   => "value1",
                                                          :source  => "openshift"},
                                                         {:section => "docker_labels",
                                                          :name    => "key2",
                                                          :value   => "value2",
                                                          :source  => "openshift"}]
                         )
    end

    it "handles openshift images without dockerImageManifest and dockerImageMetadata" do
      expect(parser.send(:parse_openshift_image,
                         image_without_dockerImage_fields).except(:registered_on)).to eq(
                           :container_image_registry => nil,
                           :digest                   => nil,
                           :image_ref                => "docker-pullable://sha256:abcdefg",
                           :name                     => "sha256",
                           :tag                      => "abcdefg"
                         )
    end

    it "doesn't add duplicated images" do
      parser.instance_variable_get('@data')[:container_images] = [{
        :name          => image_name,
        :tag           => image_tag,
        :digest        => image_digest,
        :image_ref     => image_ref,
        :registered_on => Time.now.utc - 2.minutes
      },]
      parser.instance_variable_get('@data_index').store_path(
        :container_image,
        :by_ref_and_registry_host_port,
        "#{image_registry}:#{image_registry_port}:#{image_ref}",
        parser.instance_variable_get('@data')[:container_images][0])

      inventory = {"image" => [image_from_openshift,]}

      parser.get_openshift_images(inventory)
      expect(parser.instance_variable_get('@data')[:container_images].size).to eq(1)
      expect(parser.instance_variable_get('@data')[:container_images][0]).to eq(
        parser.instance_variable_get('@data_index')[:container_image][:by_ref_and_registry_host_port].values[0])
      expect(parser.instance_variable_get('@data')[:container_images][0][:architecture]).to eq('amd64')
    end
  end

  describe "parse_build" do
    it "handles simple data" do
      expect(parser.send(:parse_build,
                         RecursiveOpenStruct.new(
                           :metadata => {
                             :name              => 'ruby-sample-build',
                             :namespace         => 'test-namespace',
                             :uid               => 'af3d1a10-44c0-11e5-b186-0aaeec44370e',
                             :resourceVersion   => '165339',
                             :creationTimestamp => '2015-08-17T09:16:46Z',
                           },
                           :spec     => {
                             :serviceAccount            => 'service_account_name',
                             :source                    => {
                               :type => 'Git',
                               :git  => {
                                 :uri => 'http://my/git/repo.git',
                               }
                             },
                             :output                    => {
                               :to => {
                                 :name => 'spec_output_to_name',
                               },
                             },
                             :completionDeadlineSeconds => '11',
                           }
                         )
                        )).to eq(:name                        => 'ruby-sample-build',
                                 :ems_ref                     => 'af3d1a10-44c0-11e5-b186-0aaeec44370e',
                                 :namespace                   => 'test-namespace',
                                 :ems_created_on              => '2015-08-17T09:16:46Z',
                                 :resource_version            => '165339',
                                 :service_account             => 'service_account_name',
                                 :project                     => nil,

                                 :build_source_type           => 'Git',
                                 :source_binary               => nil,
                                 :source_dockerfile           => nil,
                                 :source_git                  => 'http://my/git/repo.git',
                                 :source_context_dir          => nil,
                                 :source_secret               => nil,

                                 :output_name                 => 'spec_output_to_name',

                                 :completion_deadline_seconds => '11',
                                 :labels                      => [],
                                 :tags                        => []
                                )
    end
  end

  describe "parse_build_pod" do
    it "handles simple data" do
      expect(parser.send(:parse_build_pod,
                         RecursiveOpenStruct.new(
                           :metadata => {
                             :name              => 'ruby-sample-build-1',
                             :namespace         => 'test-namespace',
                             :uid               => 'af3d1a10-44c0-11e5-b186-0aaeec44370e',
                             :resourceVersion   => '165339',
                             :creationTimestamp => '2015-08-17T09:16:46Z',
                           },
                           :status   => {
                             :message                    => 'we come in peace',
                             :phase                      => 'set to stun',
                             :reason                     => 'this is a reason',
                             :duration                   => '33',
                             :completionTimestamp        => '50',
                             :startTimestamp             => '17',
                             :outputDockerImageReference => 'host:port/path/to/image'
                           }
                         ))).to eq(:name                          => 'ruby-sample-build-1',
                                   :ems_ref                       => 'af3d1a10-44c0-11e5-b186-0aaeec44370e',
                                   :namespace                     => 'test-namespace',
                                   :ems_created_on                => '2015-08-17T09:16:46Z',
                                   :resource_version              => '165339',
                                   :message                       => 'we come in peace',
                                   :phase                         => 'set to stun',
                                   :reason                        => 'this is a reason',
                                   :duration                      => '33',
                                   :completion_timestamp          => '50',
                                   :start_timestamp               => '17',
                                   :labels                        => [],
                                   :build_config                  => nil,
                                   :output_docker_image_reference => 'host:port/path/to/image'
                                  )
    end
  end

  describe "parse_template" do
    it "handles simple data" do
      expect(parser.send(:parse_template,
                         RecursiveOpenStruct.new(
                           :metadata   => {
                             :name              => 'example-template',
                             :namespace         => 'test-namespace',
                             :uid               => '22309c35-8f70-11e5-a806-001a4a231290',
                             :resourceVersion   => '172339',
                             :creationTimestamp => '2015-11-17T09:18:42Z',
                           },
                           :parameters => [
                             {'name'        => 'IMAGE_VERSION',
                              'displayName' => 'Image Version',
                              'description' => 'Specify version for metrics components',
                              'value'       => 'latest',
                              'required'    => true
                             }
                           ],
                           :objects    => []
                         ))).to eq(:name                          => 'example-template',
                                   :ems_ref                       => '22309c35-8f70-11e5-a806-001a4a231290',
                                   :namespace                     => 'test-namespace',
                                   :ems_created_on                => '2015-11-17T09:18:42Z',
                                   :resource_version              => '172339',
                                   :labels                        => [],
                                   :objects                       => [],
                                   :container_project             => nil,
                                   :container_template_parameters => [
                                     {:name         => 'IMAGE_VERSION',
                                      :display_name => 'Image Version',
                                      :description  => 'Specify version for metrics components',
                                      :value        => 'latest',
                                      :generate     => nil,
                                      :from         => nil,
                                      :required     => true
                                     }
                                   ]
                                  )
    end
  end
end
