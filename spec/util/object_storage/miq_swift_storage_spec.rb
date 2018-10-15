require "util/object_storage/miq_swift_storage"

describe MiqSwiftStorage do
  before(:each) do
    @uri = "swift://foo.com/abc/def"
    @object_storage = described_class.new(:uri => @uri, :username => 'user', :password => 'pass', :region => 'region')
  end

  it "#initialize sets the container_name" do
    container_name = @object_storage.container_name
    expect(container_name).to eq("abc/def")
  end

  it "#uri_to_object_path returns a new object path" do
    result = @object_storage.uri_to_object_path(@uri)
    expect(result).to eq("def")
  end
end
