require 'openstack/events/openstack_ceilometer_event_monitor'

describe OpenstackCeilometerEventMonitor do
  context "collecting events" do
    it 'query ceilometer nothing new' do
      connection = double
      fog_out = double
      allow(subject).to receive(:provider_connection).and_return connection
      allow(subject).to receive(:latest_event_timestamp).and_return nil
      expect(connection).to receive(:list_events).and_return fog_out
      expect(fog_out).to receive(:body).and_return []
      subject.start
      subject.each_batch do |events|
        expect(events.empty?).to be true
        subject.stop
      end
    end

    it 'query ceilometer new event' do
      connection = double
      event_data = OpenStruct.new
      event_data.event_type = 'compute.blah.start'
      event_data.generated = '2016-03-14T14:22:00.000'
      event_data.traits = [{"type" => "string", "name" => "tenant_id", "value" => "d3e8e3c7026441a98078cb1"}]
      allow(subject).to receive(:provider_connection).and_return connection
      allow(subject).to receive(:latest_event_timestamp).and_return nil
      expect(subject).to receive(:list_events).and_return [event_data]
      subject.start
      subject.each_batch do |events|
        expected_payload = {
          "event_type" => 'compute.blah.start',
          "message_id" => nil,
          "payload"    => {
            "tenant_id" => "d3e8e3c7026441a98078cb1"
          },
          "timestamp"  => "2016-03-14T14:22:00.000"
        }
        expect(events.length).to eq 1
        expect(events.first.class.name).to eq 'OpenstackEvent'
        expect(events.first.payload).to eq expected_payload
        subject.stop
      end
    end
  end
end
