describe ManageIQ::Providers::Google::CloudManager::EventParser do
  describe '.event_to_hash' do
    let(:event_name) { 'default_event' }

    shared_examples 'parses_event' do |event_type|
      let(:event_json) { read_event(event_type) }
      subject { described_class.event_to_hash(event_json, nil) }

      it "parses #{event_type} event" do
        is_expected.to include(
          :event_type => event_type,
          :source     => "GOOGLE",
          :message    => event_type,
          :timestamp  => "2018-05-21T13:36:40.472279Z",
          :full_data  => event_json,
          :ems_id     => nil
        )
      end
    end

    context "VM events" do
      it_behaves_like "parses_event", "GceOperationDone_compute.instances.delete"
      it_behaves_like "parses_event", "GceOperationDone_compute.instances.insert"
      it_behaves_like "parses_event", "GceOperationDone_compute.instances.start"
      it_behaves_like "parses_event", "GceOperationDone_compute.instances.stop"
    end
  end

  def read_event(type)
    path      = File.join(File.dirname(__FILE__), "/event_catcher/event_data/#{type}.json")
    raw_event = File.read(path)

    JSON.parse(raw_event)
  end
end
