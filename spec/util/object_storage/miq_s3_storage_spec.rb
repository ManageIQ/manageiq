require "util/object_storage/miq_s3_storage"

describe MiqS3Storage do
  before(:each) do
    @uri = "s3://tmp/abc/def"
    @session = described_class.new(:uri => @uri, :username => 'user', :password => 'pass', :region => 'region')
  end

  it "#uri_to_object_path returns a new object path" do
    result = @session.uri_to_object_key(@uri)
    expect(result).to eq("abc/def")
  end
end
