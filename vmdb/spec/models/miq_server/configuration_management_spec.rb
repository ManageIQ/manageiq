require "spec_helper"

describe MiqServer do
  describe "ConfigurationManagement" do
    describe "#get_config" do
      before do
        _guid, @local_server, _zone = EvmSpecHelper.local_guid_miq_server_zone
      end

      context "local server" do
        it "with no changes in the database" do
          expect(@local_server.get_config("vmdb").config).to be_kind_of(Hash)
        end

        it "with changes in the database" do
          c = YAML.load_file(Rails.root.join("config/vmdb.tmpl.yml"))
          c.store_path("server", "name", "XXX")
          FactoryGirl.create(:configuration, :miq_server => @local_server, :typ => "vmdb", :settings => c)

          actual = @local_server.get_config("vmdb").config.fetch_path(:server, :name)
          expect(actual).to eq "XXX"
        end
      end

      context "remote server" do
        before do
          _guid, @remote_server, _zone = EvmSpecHelper.remote_guid_miq_server_zone
        end

        it "with no changes in the database" do
          expect(@remote_server.get_config("vmdb").config).to be_kind_of(Hash)
        end

        it "with changes in the database" do
          c = YAML.load_file(Rails.root.join("config/vmdb.tmpl.yml"))
          c.store_path("server", "name", "XXX")
          FactoryGirl.create(:configuration, :miq_server => @remote_server, :typ => "vmdb", :settings => c)

          actual = @remote_server.get_config("vmdb").config.fetch_path(:server, :name)
          expect(actual).to eq "XXX"
        end
      end
    end
  end
end
