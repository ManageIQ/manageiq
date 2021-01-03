RSpec.describe ManageIQ::Session do
  describe ".revoke" do
    let(:request) { described_class.fake_request }

    def create_session
      sid, data = ManageIQ::Session.store.send(:find_session, request, nil)
      data["my_data"] = "stuff and things"
      ManageIQ::Session.store.send(:write_session, request, sid, data)

      [sid, data]
    end

    it "removes a single id" do
      sid, _data = create_session
      ManageIQ::Session.revoke([sid])

      _sid2, data2 = ManageIQ::Session.store.send(:find_session, request, sid)
      expect(data2).to eq({})
    end

    it "removes multiple sessions" do
      sid1, _data1 = create_session
      sid2, _data2 = create_session

      ManageIQ::Session.revoke(sid1, sid2)

      _, data1_v2 = ManageIQ::Session.store.send(:find_session, request, sid1)
      _, data2_v2 = ManageIQ::Session.store.send(:find_session, request, sid2)

      expect(data1_v2).to eq({})
      expect(data2_v2).to eq({})
    end
  end
end
