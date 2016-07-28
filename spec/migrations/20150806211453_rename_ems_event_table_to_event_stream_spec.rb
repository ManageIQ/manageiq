require_migration

describe RenameEmsEventTableToEventStream do
  let(:ems_event_stub)      { migration_stub(:EmsEvent) }
  let(:event_stream_stub)   { migration_stub(:EventStream) }

  migration_context :up do
    it 'adds two cloumns' do
      ems_event_stub.create!

      migrate

      event_stream = event_stream_stub.first
      expect(event_stream.type).to eq('EmsEvent')
      expect(event_stream.target_id).to be_nil
    end
  end

  migration_context :down do
    it 'deletes two cloumns' do
      event_stream_stub.create!

      migrate

      event = ems_event_stub.first
      expect(event).not_to respond_to(:type)
      expect(event).not_to respond_to(:target_id)
    end
  end
end
