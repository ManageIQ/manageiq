require "spec_helper"
require 'recursive-open-struct'

describe ManageIQ::Providers::Openshift::ContainerManager::RefreshParser do
  let(:parser) { described_class.new }

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
end
