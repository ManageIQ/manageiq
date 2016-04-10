require 'recursive-open-struct'

describe ManageIQ::Providers::Kubernetes::ContainerManager::RefreshParser do
  let(:parser)  { described_class.new }

  describe "parse_image_name" do
    example_ref = "docker://abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    example_images = [{:image_name => "example",
                       :image      => {:name => "example", :tag => nil, :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => nil},

                      {:image_name => "example:tag",
                       :image      => {:name => "example", :tag => "tag", :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => nil},

                      {:image_name => "user/example",
                       :image      => {:name => "user/example", :tag => nil, :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => nil},

                      {:image_name => "user/example:tag",
                       :image      => {:name => "user/example", :tag => "tag", :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => nil},

                      {:image_name => "example/subname/example",
                       :image      => {:name => "example/subname/example", :tag => nil, :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => nil},

                      {:image_name => "example/subname/example:tag",
                       :image      => {:name => "example/subname/example", :tag => "tag", :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => nil},

                      {:image_name => "host:1234/subname/example",
                       :image      => {:name => "subname/example", :tag => nil, :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => {:name => "host", :host => "host", :port => "1234"}},

                      {:image_name => "host:1234/subname/example:tag",
                       :image      => {:name => "subname/example", :tag => "tag", :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => {:name => "host", :host => "host", :port => "1234"}},

                      {:image_name => "host.com:1234/subname/example",
                       :image      => {:name => "subname/example", :tag => nil, :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => {:name => "host.com", :host => "host.com", :port => "1234"}},

                      {:image_name => "host.com:1234/subname/example:tag",
                       :image      => {:name => "subname/example", :tag => "tag", :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => {:name => "host.com", :host => "host.com", :port => "1234"}},

                      {:image_name => "host.com/subname/example",
                       :image      => {:name => "subname/example", :tag => nil, :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => {:name => "host.com", :host => "host.com", :port => nil}},

                      {:image_name => "host.com/example",
                       :image      => {:name => "example", :tag => nil, :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => {:name => "host.com", :host => "host.com", :port => nil}},

                      {:image_name => "host.com:1234/subname/more/names/example:tag",
                       :image      => {:name => "subname/more/names/example", :tag => "tag", :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => {:name => "host.com", :host => "host.com", :port => "1234"}},

                      {:image_name => "localhost:1234/name",
                       :image      => {:name => "name", :tag => nil, :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => {:name => "localhost", :host => "localhost", :port => "1234"}},

                      {:image_name => "localhost:1234/name@sha256:1234567abcdefg",
                       :image      => {:name => "name", :tag => nil, :digest => "sha256:1234567abcdefg",
                                       :image_ref => example_ref},
                       :registry   => {:name => "localhost", :host => "localhost", :port => "1234"}},

                      {:image_name => "example@sha256:1234567abcdefg",
                       :image      => {:name => "example", :tag => nil, :digest => "sha256:1234567abcdefg",
                                       :image_ref => example_ref},
                       :registry   => nil}]

    example_images.each do |ex|
      it "tests '#{ex[:image_name]}'" do
        result_image, result_registry = parser.send(:parse_image_name, ex[:image_name], example_ref)

        expect(result_image.except(:registered_on)).to eq(ex[:image])
        expect(result_registry).to eq(ex[:registry])
      end
    end
  end

  describe "parse_volumes" do
    example_volumes = [
      {
        :volume                => RecursiveOpenStruct.new(:name    => "example-volume1",
                                                          :gitRepo => {:repository => "default-git-repository"}),
        :name                  => "example-volume1",
        :git_repository        => "default-git-repository",
        :empty_dir_medium_type => nil,
        :gce_pd_name           => nil,
        :common_fs_type        => nil,
        :common_path           => nil,
        :common_read_only      => nil,
        :common_secret         => nil,
        :common_volume_id      => nil,
        :common_partition      => nil
      },
      {
        :volume                => RecursiveOpenStruct.new(:name     => "example-volume2",
                                                          :emptyDir => {:medium => "default-medium"}),
        :name                  => "example-volume2",
        :git_repository        => nil,
        :empty_dir_medium_type => "default-medium",
        :gce_pd_name           => nil,
        :common_fs_type        => nil,
        :common_path           => nil,
        :common_read_only      => nil,
        :common_secret         => nil,
        :common_volume_id      => nil,
        :common_partition      => nil
      },
      {
        :volume                => RecursiveOpenStruct.new(:name              => "example-volume3",
                                                          :gcePersistentDisk => {:pdName => "example-pd-name",
                                                                                 :fsType => "default-fs-type"}),
        :name                  => "example-volume3",
        :git_repository        => nil,
        :empty_dir_medium_type => nil,
        :gce_pd_name           => "example-pd-name",
        :common_fs_type        => "default-fs-type",
        :common_path           => nil,
        :common_read_only      => nil,
        :common_secret         => nil,
        :common_volume_id      => nil,
        :common_partition      => nil
      },
      {
        :volume                => RecursiveOpenStruct.new(:name                 => "example-volume4",
                                                          :awsElasticBlockStore => {:fsType => "example-fs-type"}),
        :name                  => "example-volume4",
        :git_repository        => nil,
        :empty_dir_medium_type => nil,
        :gce_pd_name           => nil,
        :common_fs_type        => "example-fs-type",
        :common_path           => nil,
        :common_read_only      => nil,
        :common_secret         => nil,
        :common_volume_id      => nil,
        :common_partition      => nil
      },
      {
        :volume                => RecursiveOpenStruct.new(:name => "example-volume5",
                                                          :nfs  => {:path     => "example-path",
                                                                    :readOnly => true}),
        :name                  => "example-volume5",
        :git_repository        => nil,
        :empty_dir_medium_type => nil,
        :gce_pd_name           => nil,
        :common_fs_type        => nil,
        :common_path           => "example-path",
        :common_read_only      => true,
        :common_secret         => nil,
        :common_volume_id      => nil,
        :common_partition      => nil
      },
      {
        :volume                => RecursiveOpenStruct.new(:name     => "example-volume6",
                                                          :hostPath => {:path => "default-path"}),
        :name                  => "example-volume6",
        :git_repository        => nil,
        :empty_dir_medium_type => nil,
        :gce_pd_name           => nil,
        :common_fs_type        => nil,
        :common_path           => "default-path",
        :common_read_only      => nil,
        :common_secret         => nil,
        :common_volume_id      => nil,
        :common_partition      => nil
      },
      {
        :volume                => RecursiveOpenStruct.new(:name => "example-volume7",
                                                          :rbd  => {:fsType   => "user-fs-type",
                                                                    :readOnly => false}),
        :name                  => "example-volume7",
        :git_repository        => nil,
        :empty_dir_medium_type => nil,
        :gce_pd_name           => nil,
        :common_fs_type        => "user-fs-type",
        :common_path           => nil,
        :common_read_only      => false,
        :common_secret         => nil,
        :common_volume_id      => nil,
        :common_partition      => nil
      },
      {
        :volume                => RecursiveOpenStruct.new(:name   => "example-volume8",
                                                          :secret => {:secretName => "example-secret"}),
        :name                  => "example-volume8",
        :git_repository        => nil,
        :empty_dir_medium_type => nil,
        :gce_pd_name           => nil,
        :common_fs_type        => nil,
        :common_path           => nil,
        :common_read_only      => nil,
        :common_secret         => "example-secret",
        :common_volume_id      => nil,
        :common_partition      => nil
      },
      {
        :volume                => RecursiveOpenStruct.new(:name   => "example-volume9",
                                                          :cinder => {:volumeId => "example-id"}),
        :name                  => "example-volume9",
        :git_repository        => nil,
        :empty_dir_medium_type => nil,
        :gce_pd_name           => nil,
        :common_fs_type        => nil,
        :common_path           => nil,
        :common_read_only      => nil,
        :common_secret         => nil,
        :common_volume_id      => "example-id",
        :common_partition      => nil
      },
      {
        :volume                => RecursiveOpenStruct.new(:name              => "example-volume10",
                                                          :gcePersistentDisk => {:partition => "default-partition"}),
        :name                  => "example-volume10",
        :git_repository        => nil,
        :empty_dir_medium_type => nil,
        :gce_pd_name           => nil,
        :common_fs_type        => nil,
        :common_path           => nil,
        :common_read_only      => nil,
        :common_secret         => nil,
        :common_volume_id      => nil,
        :common_partition      => "default-partition"
      }
    ]

    it "tests example volumes" do
      parsed_volumes = parser.send(:parse_volumes, example_volumes.collect { |ex| ex[:volume] })

      example_volumes.zip(parsed_volumes).each do |example, parsed|
        expect(parsed).to have_attributes(
          :name                  => example[:name],
          :git_repository        => example[:git_repository],
          :empty_dir_medium_type => example[:empty_dir_medium_type],
          :gce_pd_name           => example[:gce_pd_name],
          :common_fs_type        => example[:common_fs_type],
          :common_path           => example[:common_path],
          :common_read_only      => example[:common_read_only],
          :common_secret         => example[:common_secret],
          :common_volume_id      => example[:common_volume_id],
          :common_partition      => example[:common_partition]
        )
      end
    end
  end

  describe "parse_component_statuses" do
    example_component_statuses = [
      {
        :component_status => RecursiveOpenStruct.new(
          :metadata   => {:name => "example-component-status1"},
          :conditions => [
            RecursiveOpenStruct.new(
              :type    => "Healthy",
              :status  => "True",
              :message => "{'health': 'true'}"
            )
          ]),
        :name             => "example-component-status1",
        :condition        => "Healthy",
        :status           => "True",
        :message          => "{'health': 'true'}",
        :error            => nil
      },
      {
        :component_status => RecursiveOpenStruct.new(
          :metadata   => {:name => "example-component-status2"},
          :conditions => [
            RecursiveOpenStruct.new(
              :type   => "Healthy",
              :status => "Unknown",
              :error  => "Get http://127.0.0.1:10251/healthz: dial tcp 127.0.0.1:10251: connection refused"
            )
          ]),
        :name             => "example-component-status2",
        :condition        => "Healthy",
        :status           => "Unknown",
        :message          => nil,
        :error            => "Get http://127.0.0.1:10251/healthz: dial tcp 127.0.0.1:10251: connection refused"
      }
    ]

    example_component_statuses.each do |ex|
      it "tests '#{ex[:name]}'" do
        parsed_component_status = parser.send(:parse_component_status, ex[:component_status])

        expect(parsed_component_status).to have_attributes(
          :name      => ex[:name],
          :condition => ex[:condition],
          :status    => ex[:status],
          :message   => ex[:message],
          :error     => ex[:error]
        )
      end
    end
  end

  describe "parse_iec_number" do
    it "converts IEC bytes size to integer value" do
      [
        ["0",    0],
        ["1",    1],
        ["10",   10],
        ["1Ki",  1_024],
        ["7Ki",  7_168],
        ["10Ki", 10_240],
        ["1Mi",  1_048_576],
        ["3Mi",  3_145_728],
        ["10Mi", 10_485_760],
        ["1Gi",  1_073_741_824],
        ["1Ti",  1_099_511_627_776]
      ].each do |iec, bytes|
        expect(parser.send(:parse_iec_number, iec)).to eq(bytes)
      end
    end
  end

  describe "quota parsing" do
    it "handles simple data" do
      expect(parser.send(
        :parse_quota,
        RecursiveOpenStruct.new(
          :metadata => {
            :name              => 'test-quota',
            :namespace         => 'test-namespace',
            :uid               => 'af3d1a10-44c0-11e5-b186-0aaeec44370e',
            :resourceVersion   => '165339',
            :creationTimestamp => '2015-08-17T09:16:46Z',
          },
          :spec     => {
            :hard => {
              :cpu => '30'
            }
          },
          :status   => {
            :hard => {
              :cpu => '30'
            },
            :used => {
              :cpu => '100m'
            }
          }
        )
      )).to eq(:name                  => 'test-quota',
               :ems_ref               => 'af3d1a10-44c0-11e5-b186-0aaeec44370e',
               :ems_created_on        => '2015-08-17T09:16:46Z',
               :resource_version      => '165339',
               :project               => nil,
               :container_quota_items => [
                 {
                   :resource       => "cpu",
                   :quota_desired  => "30",
                   :quota_enforced => "30",
                   :quota_observed => "100m"
                 }
               ]
              )
    end

    it "handles quotas with no specification" do
      expect(parser.send(:parse_quota,
                         RecursiveOpenStruct.new(
                           :metadata => {
                             :name              => 'test-quota',
                             :namespace         => 'test-namespace',
                             :uid               => 'af3d1a10-44c0-11e5-b186-0aaeec44370e',
                             :resourceVersion   => '165339',
                             :creationTimestamp => '2015-08-17T09:16:46Z',
                           },
                           :spec     => {},
                           :status   => {})))
        .to eq(:name                  => 'test-quota',
               :ems_ref               => 'af3d1a10-44c0-11e5-b186-0aaeec44370e',
               :ems_created_on        => '2015-08-17T09:16:46Z',
               :resource_version      => '165339',
               :project               => nil,
               :container_quota_items => [])
    end

    it "handles quotas with no status" do
      expect(parser.send(:parse_quota,
                         RecursiveOpenStruct.new(
                           :metadata => {
                             :name              => 'test-quota',
                             :namespace         => 'test-namespace',
                             :uid               => 'af3d1a10-44c0-11e5-b186-0aaeec44370e',
                             :resourceVersion   => '165339',
                             :creationTimestamp => '2015-08-17T09:16:46Z'},
                           :spec     => {
                             :hard => {
                               :cpu => '30'
                             }},
                           :status   => {})))
        .to eq(:name                  => 'test-quota',
               :ems_ref               => 'af3d1a10-44c0-11e5-b186-0aaeec44370e',
               :ems_created_on        => '2015-08-17T09:16:46Z',
               :resource_version      => '165339',
               :project               => nil,
               :container_quota_items => [
                 {
                   :resource       => "cpu",
                   :quota_desired  => "30",
                   :quota_enforced => nil,
                   :quota_observed => nil
                 }
               ])
    end
  end

  describe "limit range parsing" do
    it "handles all limit types" do
      from_k8s = {
        :metadata => {
          :name              => 'test-range',
          :namespace         => 'test-namespace',
          :uid               => 'af3d1a10-44c0-11e5-b186-0aaeec44370e',
          :resourceVersion   => '2',
          :creationTimestamp => '2015-08-17T09:16:46Z',
        },
        :spec     => {
          :limits => [
            {
              :type => 'Container',
            }
          ]
        },
      }
      parsed = {
        :name                  => 'test-range',
        :ems_ref               => 'af3d1a10-44c0-11e5-b186-0aaeec44370e',
        :ems_created_on        => '2015-08-17T09:16:46Z',
        :resource_version      => '2',
        :project               => nil,
        :container_limit_items => [
          {
            :item_type               => "Container",
            :resource                => "cpu",
            :max                     => nil,
            :min                     => nil,
            :default                 => nil,
            :default_request         => nil,
            :max_limit_request_ratio => nil
          }
        ]
      }
      %w(min max default defaultRequest maxLimitRequestRatio).each do |k8s_name|
        from_k8s[:spec][:limits][0][k8s_name.to_sym] = {:cpu => '512Mi'}
        parsed[:container_limit_items][0][k8s_name.underscore.to_sym] = '512Mi'
        # note each iteration ADDS ANOTHER limit type to data & result
        expect(parser.send(:parse_range, RecursiveOpenStruct.new(from_k8s))).to eq(parsed)
      end
    end

    it "handles missing limits specification" do
      metadata = {
        :name              => 'test-range',
        :namespace         => 'test-namespace',
        :uid               => 'af3d1a10-44c0-11e5-b186-0aaeec44370e',
        :resourceVersion   => '2',
        :creationTimestamp => '2015-08-17T09:16:46Z',
      }
      ranges = [
        {:metadata => metadata},
        {:metadata => metadata, :spec => nil},
        {:metadata => metadata, :spec => {}},
        {:metadata => metadata, :spec => {:limits => nil}},
        {:metadata => metadata, :spec => {:limits => []}}
      ]
      parsed = {
        :name                  => 'test-range',
        :ems_ref               => 'af3d1a10-44c0-11e5-b186-0aaeec44370e',
        :ems_created_on        => '2015-08-17T09:16:46Z',
        :resource_version      => '2',
        :project               => nil,
        :container_limit_items => []
      }
      ranges.each do |range|
        expect(parser.send(:parse_range, RecursiveOpenStruct.new(range)))
          .to eq(parsed)
      end
    end
  end

  describe "parse_container_image" do
    shared_image_without_host = "shared/image"
    shared_image_with_host = "host:1234/shared/image"
    shared_ref = "shared:ref"
    unique_ref = "unique:ref"

    it "returns unique object *identity* for same image but different ref/id" do
      [shared_image_with_host, shared_image_without_host].each do |shared_image|
        first_obj  = parser.parse_container_image(shared_image, shared_ref)
        second_obj = parser.parse_container_image(shared_image, unique_ref)

        expect(first_obj).not_to be(second_obj)
      end
    end

    it "returns unique object *content* for same image but different ref/id" do
      [shared_image_with_host, shared_image_without_host].each do |shared_image|
        first_obj  = parser.parse_container_image(shared_image, shared_ref)
        second_obj = parser.parse_container_image(shared_image, unique_ref)

        expect(first_obj).not_to eq(second_obj)
      end
    end

    it "returns same object *identity* for same image and ref/id" do
      [shared_image_with_host, shared_image_without_host].each do |shared_image|
        first_obj  = parser.parse_container_image(shared_image, shared_ref)
        second_obj = parser.parse_container_image(shared_image, shared_ref)

        expect(first_obj).to be(second_obj)
      end
    end
  end

  describe "parse_node" do
    it "handles node without capacity" do
      expect(parser.send(
        :parse_node,
        RecursiveOpenStruct.new(
          :metadata => {
            :name              => 'test-node',
            :uid               => 'f0c1fe7e-9c09-11e5-bb22-28d2447dcefe',
            :resourceVersion   => '369104',
            :creationTimestamp => '2015-12-06T11:10:21Z'
          },
          :spec     => {
            :externalID => '10.35.17.99'
          },
          :status   => {
            :nodeInfo => {
              :machineID  => 'id',
              :systemUUID => 'uuid'
            }
          }
        )
      )).to eq({
        :name                       => 'test-node',
        :ems_ref                    => 'f0c1fe7e-9c09-11e5-bb22-28d2447dcefe',
        :ems_created_on             => '2015-12-06T11:10:21Z',
        :container_conditions       => [],
        :container_runtime_version  => nil,
        :identity_infra             => '10.35.17.99',
        :identity_machine           => 'id',
        :identity_system            => 'uuid',
        :kubernetes_kubelet_version => nil,
        :kubernetes_proxy_version   => nil,
        :labels                     => [],
        :lives_on_id                => nil,
        :lives_on_type              => nil,
        :max_container_groups       => nil,
        :computer_system            => {
          :hardware         => {
            :cpu_total_cores => nil,
            :memory_mb       => nil
          },
          :operating_system => {
            :distribution   => nil,
            :kernel_version => nil
          }
        },
        :namespace                  => nil,
        :resource_version           => '369104',
        :type                       => 'ManageIQ::Providers::Kubernetes::ContainerManager::ContainerNode'
      })
    end

    it "handles node without memory, cpu and pods" do
      expect(parser.send(
        :parse_node,
        RecursiveOpenStruct.new(
          :metadata => {
            :name              => 'test-node',
            :uid               => 'f0c1fe7e-9c09-11e5-bb22-28d2447dcefe',
            :resourceVersion   => '3691041',
            :creationTimestamp => '2015-12-06T11:10:21Z'
          },
          :spec     => {
            :externalID => '10.35.17.99'
          },
          :status   => {
            :nodeInfo => {
              :machineID  => 'id',
              :systemUUID => 'uuid'
            },
            :capacity => {}
          }
        )
      )).to eq({
        :name                       => 'test-node',
        :ems_ref                    => 'f0c1fe7e-9c09-11e5-bb22-28d2447dcefe',
        :ems_created_on             => '2015-12-06T11:10:21Z',
        :container_conditions       => [],
        :container_runtime_version  => nil,
        :identity_infra             => '10.35.17.99',
        :identity_machine           => 'id',
        :identity_system            => 'uuid',
        :kubernetes_kubelet_version => nil,
        :kubernetes_proxy_version   => nil,
        :labels                     => [],
        :lives_on_id                => nil,
        :lives_on_type              => nil,
        :max_container_groups       => nil,
        :computer_system            => {
          :hardware         => {
            :cpu_total_cores => nil,
            :memory_mb       => nil
          },
          :operating_system => {
            :distribution   => nil,
            :kernel_version => nil
          }
        },
        :namespace                  => nil,
        :resource_version           => '3691041',
        :type                       => 'ManageIQ::Providers::Kubernetes::ContainerManager::ContainerNode'
      })
    end

    it "handles node without nodeInfo" do
      expect(parser.send(
        :parse_node,
        RecursiveOpenStruct.new(
          :metadata => {
            :name              => 'test-node',
            :uid               => 'f0c1fe7e-9c09-11e5-bb22-28d2447dcefe',
            :resourceVersion   => '369104',
            :creationTimestamp => '2016-01-01T11:10:21Z'
          },
          :spec     => {
            :externalID => '10.35.17.99'
          },
          :status   => {
            :capacity => {}
          }
        )
      )).to eq(
        {
          :name                 => 'test-node',
          :ems_ref              => 'f0c1fe7e-9c09-11e5-bb22-28d2447dcefe',
          :ems_created_on       => '2016-01-01T11:10:21Z',
          :container_conditions => [],
          :identity_infra       => '10.35.17.99',
          :labels               => [],
          :lives_on_id          => nil,
          :lives_on_type        => nil,
          :max_container_groups => nil,
          :computer_system      => {
            :hardware         => {
              :cpu_total_cores => nil,
              :memory_mb       => nil
            },
            :operating_system => {
              :distribution   => nil,
              :kernel_version => nil
            }
          },
          :namespace            => nil,
          :resource_version     => '369104',
          :type                 => 'ManageIQ::Providers::Kubernetes::ContainerManager::ContainerNode'
        })
    end
  end

  describe "parse_persistent_volume" do
    it "tests parent type" do
      expect(parser.send(
        :parse_persistent_volume,
        RecursiveOpenStruct.new(
          :metadata => {
            :name              => 'test-volume',
            :uid               => '66213621-80a1-11e5-b907-28d2447dcefe',
            :resourceVersion   => '448015',
            :creationTimestamp => '2015-12-06T11:10:21Z'
          },
          :spec     => {
            :capacity    => {
              :storage => '10Gi'
            },
            :hostPath    => {
              :path => '/tmp/data01'
            },
            :accessModes => ['ReadWriteOnce'],
          },
          :status   => {
            :phase => 'Available'
          }
        )
      )).to eq(
        {
          :name                    => 'test-volume',
          :ems_ref                 => '66213621-80a1-11e5-b907-28d2447dcefe',
          :ems_created_on          => '2015-12-06T11:10:21Z',
          :namespace               => nil,
          :resource_version        => '448015',
          :type                    => 'PersistentVolume',
          :status_phase            => 'Available',
          :access_modes            => 'ReadWriteOnce',
          :capacity                => 'storage=10Gi',
          :claim_name              => nil,
          :common_fs_type          => nil,
          :common_partition        => nil,
          :common_path             => '/tmp/data01',
          :common_read_only        => nil,
          :common_secret           => nil,
          :common_volume_id        => nil,
          :empty_dir_medium_type   => nil,
          :gce_pd_name             => nil,
          :git_repository          => nil,
          :git_revision            => nil,
          :glusterfs_endpoint_name => nil,
          :iscsi_iqn               => nil,
          :iscsi_lun               => nil,
          :iscsi_target_portal     => nil,
          :nfs_server              => nil,
          :parent_type             => 'ManageIQ::Providers::ContainerManager',
          :rbd_ceph_monitors       => '',
          :rbd_image               => nil,
          :rbd_keyring             => nil,
          :rbd_pool                => nil,
          :rbd_rados_user          => nil,
          :reclaim_policy          => nil,
          :status_message          => nil,
          :status_reason           => nil
        })
    end
  end
end
