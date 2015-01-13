require "spec_helper"

describe MiqServer do
  context "LogManagement" do
    before do
      _, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone
      @miq_server2          = FactoryGirl.create(:miq_server, :zone => @zone)
    end

    context "#synchronize_logs" do
      it "passes along server override" do
        @miq_server.synchronize_logs("system", @miq_server2)
        expect(MiqTask.first.miq_server_id).to eql @miq_server2.id
        expect(MiqQueue.first.args.first[:id]).to eql @miq_server2.id
      end

      it "passes 'self' server if no server arg" do
        @miq_server2.synchronize_logs("system")
        expect(MiqTask.first.miq_server_id).to eql @miq_server2.id
        expect(MiqQueue.first.args.first[:id]).to eql @miq_server2.id
      end
    end

    context "#get_log_depot_settings" do
      let(:depot_hash) do
        {:uri      => uri,
         :username => "user",
         :password => "pass",
         :name     => "File Depot"}
      end

      let(:depot)          { FactoryGirl.build(:file_depot, :uri => uri) { |d| d.save(:validate => false) } }
      let(:new_depot_hash) { {:uri => "nfs://server.example.com", :username => "new_user", :password => "new_pass"} }
      let(:uri)            { "smb://server/share" }

      before do
        depot.update_authentication(:default => {:userid => "user", :password => "pass"})
      end

      it "set on miq_server" do
        @miq_server.update_attributes(:log_file_depot_id => depot.id)

        expect(@miq_server.get_log_depot_settings).to eq(depot_hash)
      end

      it "set on zone" do
        @zone.update_attributes(:log_file_depot_id => depot.id)

        expect(@miq_server.get_log_depot_settings).to eq({:from_zone => true}.merge(depot_hash))
      end
    end
  end
end
