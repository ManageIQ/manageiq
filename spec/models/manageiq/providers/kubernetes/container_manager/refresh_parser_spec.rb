require "spec_helper"
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

        result_image.should == ex[:image]
        result_registry.should == ex[:registry]
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
        parsed.should have_attributes(
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
end
