require 'openstack/amqp/openstack_ceilometer_event_converter'

describe OpenstackCeilometerEventConverter do
  let(:fog_event) do
    fog_event = OpenStruct.new
    fog_event.message_id = "b1aa359a-00ed-4af2-9294-4860d9000dd"
    fog_event.event_type = "scheduler.select_destinations.start"
    fog_event.generated = "2016-03-13T16:59:01.760000"
    fog_event.raw = {}
    fog_event.traits = [{"type" => "string", "name" => "tenant_id", "value" => "d3e8e3c7026441a98078cb1"},
                        {"type" => "string", "name" => "service", "value" => "scheduler.dhcp-8-99.local"}]
    fog_event
  end

  let(:converter) { OpenstackCeilometerEventConverter.new(fog_event) }

  context 'convert ceilometer event to ampq format' do
    it 'return metadata' do
      expected_metadata = {:user_id => nil, :priority => nil, :content_type => nil}
      expect(converter.metadata).to eq expected_metadata
    end

    it 'return payload' do
      expected_ampq_payload = {
        "message_id" => "b1aa359a-00ed-4af2-9294-4860d9000dd",
        "event_type" => "scheduler.select_destinations.start",
        "timestamp"  => "2016-03-13T16:59:01.760000",
        "payload"    => {
          "tenant_id" => "d3e8e3c7026441a98078cb1",
          "service"   => "scheduler.dhcp-8-99.local"}
      }
      expect(converter.payload).to eq expected_ampq_payload
    end
  end
end
