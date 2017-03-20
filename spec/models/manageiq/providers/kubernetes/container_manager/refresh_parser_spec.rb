require 'recursive-open-struct'

describe ManageIQ::Providers::Kubernetes::ContainerManager::RefreshParser do
  let(:parser)  { described_class.new }

  describe "parse_namespace" do
    it "handles simple data" do
      expect(parser.send(:parse_namespace,
                         RecursiveOpenStruct.new(
                           :metadata => {
                             :name              => "proj2",
                             :selfLink          => "/api/v1/namespaces/proj2",
                             :uid               => "554c1eaa-f4f6-11e5-b943-525400c7c086",
                             :resourceVersion   => "150569",
                             :creationTimestamp => "2016-03-28T15:04:13Z",
                             :labels            => {:department => "Warp-drive"},
                             :annotations       => {:"openshift.io/description"  => "",
                                                    :"openshift.io/display-name" => "Project 2"}
                           },
                           :spec     => {:finalizers => ["openshift.io/origin", "kubernetes"]},
                           :status   => {:phase => "Active"}
                         )
                        )).to eq(:ems_ref          => "554c1eaa-f4f6-11e5-b943-525400c7c086",
                                 :name             => "proj2",
                                 :ems_created_on   => "2016-03-28T15:04:13Z",
                                 :resource_version => "150569",
                                 :labels           => [
                                   {
                                     :section => "labels",
                                     :name    => "department",
                                     :value   => "Warp-drive",
                                     :source  => "kubernetes"
                                   }
                                 ],
                                 :tags             => [])
    end
  end

  describe "parse_image_name" do
    example_ref = "docker://abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    example_images = [{:image_name => "example",
                       :image_ref  => example_ref,
                       :image      => {:name => "example", :tag => nil, :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => nil},

                      {:image_name => "example:tag",
                       :image_ref  => example_ref,
                       :image      => {:name => "example", :tag => "tag", :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => nil},

                      {:image_name => "user/example",
                       :image_ref  => example_ref,
                       :image      => {:name => "user/example", :tag => nil, :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => nil},

                      {:image_name => "user/example:tag",
                       :image_ref  => example_ref,
                       :image      => {:name => "user/example", :tag => "tag", :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => nil},

                      {:image_name => "example/subname/example",
                       :image_ref  => example_ref,
                       :image      => {:name => "example/subname/example", :tag => nil, :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => nil},

                      {:image_name => "example/subname/example:tag",
                       :image_ref  => example_ref,
                       :image      => {:name => "example/subname/example", :tag => "tag", :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => nil},

                      {:image_name => "host:1234/subname/example",
                       :image_ref  => example_ref,
                       :image      => {:name => "subname/example", :tag => nil, :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => {:name => "host", :host => "host", :port => "1234"}},

                      {:image_name => "host:1234/subname/example:tag",
                       :image_ref  => example_ref,
                       :image      => {:name => "subname/example", :tag => "tag", :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => {:name => "host", :host => "host", :port => "1234"}},

                      {:image_name => "host.com:1234/subname/example",
                       :image_ref  => example_ref,
                       :image      => {:name => "subname/example", :tag => nil, :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => {:name => "host.com", :host => "host.com", :port => "1234"}},

                      {:image_name => "host.com:1234/subname/example:tag",
                       :image_ref  => example_ref,
                       :image      => {:name => "subname/example", :tag => "tag", :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => {:name => "host.com", :host => "host.com", :port => "1234"}},

                      {:image_name => "host.com/subname/example",
                       :image_ref  => example_ref,
                       :image      => {:name => "subname/example", :tag => nil, :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => {:name => "host.com", :host => "host.com", :port => nil}},

                      {:image_name => "host.com/example",
                       :image_ref  => example_ref,
                       :image      => {:name => "example", :tag => nil, :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => {:name => "host.com", :host => "host.com", :port => nil}},

                      {:image_name => "host.com:1234/subname/more/names/example:tag",
                       :image_ref  => example_ref,
                       :image      => {:name => "subname/more/names/example", :tag => "tag", :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => {:name => "host.com", :host => "host.com", :port => "1234"}},

                      {:image_name => "localhost:1234/name",
                       :image_ref  => example_ref,
                       :image      => {:name => "name", :tag => nil, :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => {:name => "localhost", :host => "localhost", :port => "1234"}},

                      {:image_name => "localhost:1234/name@sha256:1234567abcdefg",
                       :image_ref  => example_ref,
                       :image      => {:name => "name", :tag => nil, :digest => "sha256:1234567abcdefg",
                                       :image_ref => "docker-pullable://localhost:1234/name@sha256:1234567abcdefg"},
                       :registry   => {:name => "localhost", :host => "localhost", :port => "1234"}},

                      # host with no port. more than one subdomain (a.b.c.com)
                      {:image_name => "reg.access.rh.com/openshift3/image-inspector",
                       :image_ref  => example_ref,
                       :image      => {:name => "openshift3/image-inspector", :tag => nil, :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => {:name => "reg.access.rh.com", :host => "reg.access.rh.com", :port => nil}},

                      # host with port. more than one subdomain (a.b.c.com:1234)
                      {:image_name => "host.access.com:1234/subname/more/names/example:tag",
                       :image_ref  => example_ref,
                       :image      => {:name => "subname/more/names/example", :tag => "tag", :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => {:name => "host.access.com", :host => "host.access.com", :port => "1234"}},

                      # localhost no port
                      {:image_name => "localhost/name",
                       :image_ref  => example_ref,
                       :image      => {:name => "name", :tag => nil, :digest => nil,
                                       :image_ref => example_ref},
                       :registry   => {:name => "localhost", :host => "localhost", :port => nil}},

                      # tag and digest together
                      {:image_name => "reg.example.com:1234/name1:tagos@sha256:123abcdef",
                       :image_ref  => example_ref,
                       :image      => {:name => "name1", :tag => "tagos", :digest => "sha256:123abcdef",
                                       :image_ref => "docker-pullable://reg.example.com:1234/name1@sha256:123abcdef"},
                       :registry   => {:name => "reg.example.com", :host => "reg.example.com", :port => "1234"}},

                      # digest from new docker-pullable
                      {:image_name => "reg.example.com:1234/name1:tagos",
                       :image_ref  => "docker-pullable://reg.example.com:1234/name1@sha256:321bcd",
                       :image      => {:name => "name1", :tag => "tagos", :digest => "sha256:321bcd",
                                       :image_ref => "docker-pullable://reg.example.com:1234/name1@sha256:321bcd"},
                       :registry   => {:name => "reg.example.com", :host => "reg.example.com", :port => "1234"}},

                      {:image_name => "example@sha256:1234567abcdefg",
                       :image_ref  => example_ref,
                       :image      => {:name => "example", :tag => nil, :digest => "sha256:1234567abcdefg",
                                       :image_ref => "docker-pullable://example@sha256:1234567abcdefg"},
                       :registry   => nil}]

    example_images.each do |ex|
      it "tests '#{ex[:image_name]}'" do
        result_image, result_registry = parser.send(:parse_image_name, ex[:image_name], ex[:image_ref])

        expect(result_image.except(:registered_on)).to eq(ex[:image])
        expect(result_registry).to eq(ex[:registry])
      end
    end
  end

  describe "parse_container_state" do
    # check https://bugzilla.redhat.com/show_bug.cgi?id=1383498
    it "handles nil input" do
      expect(parser.send(:parse_container_state, nil)).to eq({})
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

    pod = RecursiveOpenStruct.new(
      :metadata => {
        :name              => 'test-pod',
        :namespace         => 'test-namespace',
        :uid               => 'af3d1a10-23d3-11e5-44c0-0af3d1a10370e',
        :resourceVersion   => '3691041',
        :creationTimestamp => '2015-08-17T09:16:46Z',
      },
      :spec     => {
        :volumes => example_volumes.collect { |ex| ex[:volume] }
      }
    )

    it "tests example volumes" do
      parsed_volumes = parser.send(:parse_volumes, pod)

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
        expect(iec.to_iec_integer).to eq(bytes)
      end
    end

    it "parse capacity hash correctly" do
      hash = {:storage => "10Gi", :foo => "10"}
      expect(parser.send(:parse_resource_list, hash)).to eq({:storage => 10.gigabytes, :foo => 10})
    end

    it "parse capacity hash with bad value correctly" do
      hash = {:storage => "10Gi", :foo => "10wrong"}
      expect(parser.send(:parse_resource_list, hash)).to eq({:storage => 10.gigabytes})
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
    shared_ref = "docker-pullable://host:1234/repo/image@sha256:123456"
    other_registry_ref = "docker-pullable://other-host:4321/repo/image@sha256:123456"
    unique_ref = "docker-pullable://host:1234/repo/image@sha256:abcdef"

    it "returns unique object *identity* for same image but different digest" do
      [shared_image_with_host, shared_image_without_host].each do |shared_image|
        first_obj  = parser.parse_container_image(shared_image, shared_ref)
        second_obj = parser.parse_container_image(shared_image, unique_ref)

        expect(first_obj).not_to be(second_obj)
      end
    end

    it "returns unique object *content* for same image but different digest" do
      [shared_image_with_host, shared_image_without_host].each do |shared_image|
        first_obj  = parser.parse_container_image(shared_image, shared_ref)
        second_obj = parser.parse_container_image(shared_image, unique_ref)

        expect(first_obj).not_to eq(second_obj)
      end
    end

    it "returns same object *identity* for same digest" do
      [shared_image_with_host, shared_image_without_host].each do |shared_image|
        first_obj  = parser.parse_container_image(shared_image, shared_ref)
        second_obj = parser.parse_container_image(shared_image, shared_ref)

        expect(first_obj).to be(second_obj)
      end
    end

    it "returns same object *identity* for same digest and different repo" do
      [shared_image_with_host, shared_image_without_host].each do |shared_image|
        first_obj  = parser.parse_container_image(shared_image, other_registry_ref)
        second_obj = parser.parse_container_image(shared_image, shared_ref)

        expect(first_obj).to be(second_obj)
      end
    end
  end

  describe "cross_link_node" do
    context "expected failures" do
      before :each do
        @node = OpenStruct.new(
          :identity_system => "f0c1fe7e-9c09-11e5-bb22-28d2447dcefe",
        )
      end

      after :each do
        parser.send(:cross_link_node, @node)
        expect(@node[:lives_on_id]).to eq(nil)
        expect(@node[:lives_on_type]).to eq(nil)
      end

      it "fails when provider type is wrong" do
        @node[:identity_infra] = "aws://aws_project/europe-west1/instance_id/"
        @ems = FactoryGirl.create(:ems_google,
                                  :provider_region => "europe-west1",
                                  :project         => "aws_project")
        @vm = FactoryGirl.create(:vm_google,
                                 :ext_management_system => @ems,
                                 :name                  => "instance_id")
      end
    end

    context "succesful attempts" do
      before :each do
        @node = OpenStruct.new(
          :identity_system => "f0c1fe7e-9c09-11e5-bb22-28d2447dcefe",
        )
      end

      after :each do
        parser.send(:cross_link_node, @node)
        expect(@node[:lives_on_id]).to eq(@vm.id)
        expect(@node[:lives_on_type]).to eq(@vm.type)
      end

      it "cross links google" do
        @node[:identity_infra] = "gce://gce_project/europe-west1/instance_id/"
        @ems = FactoryGirl.create(:ems_google,
                                  :provider_region => "europe-west1",
                                  :project         => "gce_project")
        @vm = FactoryGirl.create(:vm_google,
                                 :ext_management_system => @ems,
                                 :name                  => "instance_id")
      end

      it "cross links amazon" do
        @node[:identity_infra] = "aws:///us-west-1/aws-id"
        @ems = FactoryGirl.create(:ems_amazon,
                                  :provider_region => "us-west-1")
        @vm = FactoryGirl.create(:vm_amazon,
                                 :uid_ems               => "aws-id",
                                 :ext_management_system => @ems)
      end

      it "cross links openstack through provider id" do
        @node[:identity_infra] = "openstack:///openstack_id"
        @ems = FactoryGirl.create(:ems_openstack)
        @vm = FactoryGirl.create(:vm_openstack,
                                 :uid_ems               => 'openstack_id',
                                 :ext_management_system => @ems)
      end

      it 'cross links with missing data in ProviderID' do
        @node[:identity_infra] = "gce:////instance_id/"
        @ems = FactoryGirl.create(:ems_google,
                                  :provider_region => "europe-west1",
                                  :project         => "gce_project")
        @vm = FactoryGirl.create(:vm_google,
                                 :ext_management_system => @ems,
                                 :name                  => "instance_id")
      end

      it 'cross links with malformed provider id' do
        @node[:identity_infra] = "gce://instance_id"
        @ems = FactoryGirl.create(:ems_google,
                                  :provider_region => "europe-west1",
                                  :project         => "gce_project")
        @vm = FactoryGirl.create(:vm_google,
                                 :ext_management_system => @ems,
                                 :name                  => "instance_id")
      end

      it "cross links by uuid" do
        @node[:identity_infra] = nil
        @ems = FactoryGirl.create(:ems_openstack)
        @vm = FactoryGirl.create(:vm_openstack,
                                 :uid_ems               => @node[:identity_system],
                                 :ext_management_system => @ems)
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
            :providerID => 'aws:///zone/aws-id'
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
        :identity_infra             => 'aws:///zone/aws-id',
        :identity_machine           => 'id',
        :identity_system            => 'uuid',
        :kubernetes_kubelet_version => nil,
        :kubernetes_proxy_version   => nil,
        :labels                     => [],
        :tags                       => [],
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

    it "handles node without providerID, memory, cpu and pods" do
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
        :identity_infra             => nil,
        :identity_machine           => 'id',
        :identity_system            => 'uuid',
        :kubernetes_kubelet_version => nil,
        :kubernetes_proxy_version   => nil,
        :labels                     => [],
        :tags                       => [],
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
            :providerID => 'aws:///zone/aws-id'
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
          :identity_infra       => 'aws:///zone/aws-id',
          :labels               => [],
          :tags                 => [],
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
          :capacity                => {:storage => 10.gigabytes},
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
          :persistent_volume_claim => nil,
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

  describe "parse_persistent_volume_claim" do
    it "tests pending persistent volume claim" do
      expect(parser.send(
        :parse_persistent_volume_claim,
        RecursiveOpenStruct.new(
          :metadata => {
            :name              => 'test-claim',
            :uid               => '1577c5ba-a3f6-11e5-9845-28d2447dcefe',
            :resourceVersion   => '448015',
            :creationTimestamp => '2015-12-06T11:10:21Z'
          },
          :spec     => {
            :accessModes => ['ReadWriteOnce'],
            :resources   => {
              :requests => {
                :storage => '3Gi'
              }
            },
          },
          :status   => {
            :phase => 'Pending',
          }
        )
      )).to eq(
        {
          :name                 => 'test-claim',
          :ems_ref              => '1577c5ba-a3f6-11e5-9845-28d2447dcefe',
          :ems_created_on       => '2015-12-06T11:10:21Z',
          :namespace            => nil,
          :resource_version     => '448015',
          :desired_access_modes => ['ReadWriteOnce'],
          :phase                => 'Pending',
          :actual_access_modes  => nil,
          :capacity             => {}
        })
    end

    it "tests bounded persistent volume claim" do
      expect(parser.send(
        :parse_persistent_volume_claim,
        RecursiveOpenStruct.new(
          :metadata => {
            :name              => 'test-claim',
            :uid               => '1577c5ba-a3f6-11e5-9845-28d2447dcefe',
            :resourceVersion   => '448015',
            :creationTimestamp => '2015-12-06T11:11:21Z'
          },
          :spec     => {
            :accessModes => %w('ReadWriteOnce', 'ReadWriteMany'),
            :resources   => {
              :requests => {
                :storage => '3Gi'
              }
            }
          },
          :status   => {
            :phase       => 'Bound',
            :accessModes => %w('ReadWriteOnce', 'ReadWriteMany'),
            :capacity    => {
              :storage => '10Gi'
            }
          }
        )
      )).to eq(
        {
          :name                 => 'test-claim',
          :ems_ref              => '1577c5ba-a3f6-11e5-9845-28d2447dcefe',
          :ems_created_on       => '2015-12-06T11:11:21Z',
          :namespace            => nil,
          :resource_version     => '448015',
          :desired_access_modes => %w('ReadWriteOnce', 'ReadWriteMany'),
          :phase                => 'Bound',
          :actual_access_modes  => %w('ReadWriteOnce', 'ReadWriteMany'),
          :capacity             => {:storage => 10.gigabytes}
        })
    end
  end
end
