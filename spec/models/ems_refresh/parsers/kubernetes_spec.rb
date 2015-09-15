require "spec_helper"

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
end
