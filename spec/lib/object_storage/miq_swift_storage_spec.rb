require "util/object_storage/miq_swift_storage"

describe MiqSwiftStorage do
  let(:object_storage) { described_class.new(:uri => uri, :username => 'user', :password => 'pass') }

  describe "#initialize" do
    context "using a uri with query parameters" do
      let(:uri) { "swift://foo.com:5678/abc/def?region=region&api_version=v3&security_protocol=non-ssl" }

      it "sets the container_name" do
        expect(object_storage.container_name).to eq("abc")
      end

      it "#uri_to_object_path returns a new object path" do
        result = object_storage.uri_to_object_path(uri)
        expect(result).to eq("def")
      end
    end

    context "using a uri without query parameters" do
      let(:uri) { "swift://foo.com/abc/def/my_file.tar.gz" }

      it "sets the container_name" do
        expect(object_storage.container_name).to eq("abc")
      end

      it "#uri_to_object_path returns a new object path" do
        result = object_storage.uri_to_object_path(uri)
        expect(result).to eq("def/my_file.tar.gz")
      end
    end

    context "using a uri with only a container_name" do
      let(:uri) { "swift://foo.com/container_name" }

      it "sets the container_name" do
        expect(object_storage.container_name).to eq("container_name")
      end
    end

    context "using a uri with only a container_name and params" do
      let(:uri) { "swift://foo.com/container_name?region=region&api_version=v3&security_protocol=non-ssl" }

      it "sets the container_name" do
        expect(object_storage.container_name).to eq("container_name")
      end

      it "sets the region" do
        expect(object_storage.instance_variable_get(:@region)).to eq("region")
      end

      it "sets the api_version" do
        expect(object_storage.instance_variable_get(:@api_version)).to eq("v3")
      end

      it "sets the security_protocol" do
        expect(object_storage.instance_variable_get(:@security_protocol)).to eq("non-ssl")
      end
    end
  end

  describe "#auth_url (private)" do
    context "with non-ssl security protocol" do
      let(:uri) { "swift://foo.com:5678/abc/def?region=region&api_version=v3&security_protocol=non-ssl" }

      it "sets the scheme to http" do
        expect(URI(object_storage.send(:auth_url)).scheme).to eq("http")
      end

      it "sets the host to foo.com" do
        expect(URI(object_storage.send(:auth_url)).host).to eq("foo.com")
      end

      it "unsets the query string" do
        expect(URI(object_storage.send(:auth_url)).query).to eq(nil)
      end
    end

    context "with ssl security protocol" do
      let(:uri) { "swift://foo.com:5678/abc/def?region=region&api_version=v3&security_protocol=ssl" }

      it "sets the scheme to https" do
        expect(URI(object_storage.send(:auth_url)).scheme).to eq("https")
      end

      it "sets the host to foo.com" do
        expect(URI(object_storage.send(:auth_url)).host).to eq("foo.com")
      end

      it "unsets the query string" do
        expect(URI(object_storage.send(:auth_url)).query).to eq(nil)
      end
    end

    context "with v3 api version" do
      let(:uri) { "swift://foo.com:5678/abc/def?region=region&api_version=v3&security_protocol=ssl" }

      it "sets the path to a v3 path" do
        expect(URI(object_storage.send(:auth_url)).path).to eq("/v3/auth/tokens")
      end
    end

    context "with v2 api version" do
      let(:uri) { "swift://foo.com:5678/abc/def?region=region&api_version=v2&security_protocol=ssl" }

      it "sets the path to a v2 path" do
        expect(URI(object_storage.send(:auth_url)).path).to eq("/v2.0/tokens")
      end
    end
  end
end
