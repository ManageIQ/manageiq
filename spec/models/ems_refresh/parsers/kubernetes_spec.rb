require "spec_helper"

describe EmsRefresh::Parsers::Kubernetes do
  let(:parser)  { described_class.new }

  describe "parse_image_name" do
    example_ref = "docker://abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    example_images = [{:image_name => "example",
                       :image      => {:name => "example", :tag => nil, :image_ref => example_ref},
                       :registry   => nil},

                      {:image_name => "example:tag",
                       :image      => {:name => "example", :tag => "tag", :image_ref => example_ref},
                       :registry   => nil},

                      {:image_name => "user/example",
                       :image      => {:name => "user/example", :tag => nil, :image_ref => example_ref},
                       :registry   => nil},

                      {:image_name => "user/example:tag",
                       :image      => {:name => "user/example", :tag => "tag", :image_ref => example_ref},
                       :registry   => nil},

                      {:image_name => "host/subname/example",
                       :image      => {:name => "subname/example", :tag => nil, :image_ref => example_ref},
                       :registry   => {:name => "host", :host => "host", :port => nil}},

                      {:image_name => "host/subname/example:tag",
                       :image      => {:name => "subname/example", :tag => "tag", :image_ref => example_ref},
                       :registry   => {:name => "host", :host => "host", :port => nil}},

                      {:image_name => "host:1234/subname/example",
                       :image      => {:name => "subname/example", :tag => nil, :image_ref => example_ref},
                       :registry   => {:name => "host", :host => "host", :port => "1234"}},

                      {:image_name => "host:1234/subname/example:tag",
                       :image      => {:name => "subname/example", :tag => "tag", :image_ref => example_ref},
                       :registry   => {:name => "host", :host => "host", :port => "1234"}},

                      {:image_name => "host.com:1234/subname/example",
                       :image      => {:name => "subname/example", :tag => nil, :image_ref => example_ref},
                       :registry   => {:name => "host.com", :host => "host.com", :port => "1234"}},

                      {:image_name => "host.com:1234/subname/example:tag",
                       :image      => {:name => "subname/example", :tag => "tag", :image_ref => example_ref},
                       :registry   => {:name => "host.com", :host => "host.com", :port => "1234"}},

                      {:image_name => "host.com/subname/example",
                       :image      => {:name => "subname/example", :tag => nil, :image_ref => example_ref},
                       :registry   => {:name => "host.com", :host => "host.com", :port => nil}},

                      {:image_name => "host.com:1234/subname/more/names/example:tag",
                       :image      => {:name => "subname/more/names/example", :tag => "tag", :image_ref => example_ref},
                       :registry   => {:name => "host.com", :host => "host.com", :port => "1234"}}]

    example_images.each do |ex|
      it "tests '#{ex[:image_name]}'" do
        result_image, result_registry = parser.send(:parse_image_name, ex[:image_name], example_ref)

        result_image.should == ex[:image]
        result_registry.should == ex[:registry]
      end
    end
  end
end
