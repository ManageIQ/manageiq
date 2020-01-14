require "workers/evm_server"

describe EvmServer do
  describe "#for_each_server (private)" do
    it "yields the local server when not podified" do
      server = EvmSpecHelper.local_miq_server
      subject.send(:for_each_server) do
        expect(MiqServer.my_server.guid).to eq(server.guid)
        expect(subject.instance_variable_get(:@server).guid).to eq(server.guid)
      end
    end

    context "when podified" do
      let(:expected_guids) { MiqServer.pluck(:guid) }

      before do
        4.times { FactoryBot.create(:miq_server) }
        allow(MiqEnvironment::Command).to receive(:is_podified?).and_return(true)
      end

      it "sets the server variable to each server" do
        received_guids = []
        subject.send(:for_each_server) { received_guids << subject.instance_variable_get(:@server).guid }

        expect(received_guids).to match_array(expected_guids)
      end

      it "sets my_server to each server" do
        received_guids = []
        subject.send(:for_each_server) { received_guids << MiqServer.my_server.guid }

        expect(received_guids).to match_array(expected_guids)
      end

      it "resets ::Settings to the correct server" do
        MiqServer.all.each do |server|
          server.add_settings_for_resource(:special => {:settings => {:id => server.id}})
        end

        received_ids = []
        subject.send(:for_each_server) { received_ids << ::Settings.special.settings[:id] }
        expect(received_ids).to match_array(MiqServer.pluck(:id))
      end
    end
  end
end
