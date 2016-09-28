describe ManageIQ::Providers::Hawkular::MiddlewareManager::AlertProfileManager do
  let(:client) { double('Hawkular::Alerts') }
  let(:subject) { described_class.new(client) }

  let(:server) do
    FactoryGirl.create(:hawkular_middleware_server, :name => 'Serv', :ems_ref => 'c00fee',
                       :feed => 'feed', :nativeid => 'nativeid')
  end
  let(:server2) do
    FactoryGirl.create(:hawkular_middleware_server, :name => 'Serv2', :ems_ref => 'c22fee',
                       :feed => 'feed', :nativeid => 'nativeid2')
  end

  let(:alert_id) { 2 }
  let(:group_trigger) do
    double('group_trigger', :id => 'MiQ-2', :name => 'Gtrig',
           :conditions => [
             double('condition', :data_id => 'foo', :data2_id => 'bar')
           ])
  end
  let(:server2_member_trigger) { double(:id => "MiQ-2-#{server2.id}") }

  let(:expected_map_for_group_trigger) do
    {
      'foo' => 'hm_some_prefix_MI~R~[feed/nativeid]~MT~foo',
      'bar' => 'hm_some_prefix_MI~R~[feed/nativeid]~MT~bar',
    }
  end

  context '#process_alert_profile' do
    it ':update_assignments' do
      # Assume alert 2 is added to profile 50, and it was already in profile 49.
      allow(client).to receive(:get_single_trigger).with('MiQ-2', true).and_return(group_trigger)
      allow(group_trigger).to receive(:context).and_return('miq.alert_profiles' => '49')
      allow(group_trigger).to receive(:context=).with('miq.alert_profiles' => '49,50')
      expect(client).to receive(:update_group_trigger).with(group_trigger)

      # Assume it was already assigned to Serv2, and now it's added to Serv.
      allow(client).to receive(:list_members).with(group_trigger.id).and_return([server2_member_trigger])
      expect(subject).to receive(:create_new_member).with(group_trigger, server.id)

      subject.process_alert_profile(:update_assignments,
                                    :id => 50, :old_alerts_ids => [alert_id],
                                    :old_assignments_ids => [server2.id],
                                    :new_assignments_ids => [server.id, server2.id])
    end
  end

  it '#create_new_member' do
    allow(group_trigger).to receive(:context).and_return('dataId.hm.prefix' => 'hm_some_prefix_')
    expect(client).to receive(:create_member_trigger).with(
      an_object_having_attributes(
        :group_id       => 'MiQ-2',
        :member_id      => "MiQ-2-#{server.id}",
        :member_name    => 'Gtrig for Serv',
        :member_context => {'resource_path' => 'c00fee'},
        :data_id_map    => expected_map_for_group_trigger,
      )
    )

    subject.create_new_member(group_trigger, server.id)
  end

  it 'calculate_member_data_id_map' do
    allow(group_trigger).to receive(:context).and_return('dataId.hm.prefix' => 'hm_some_prefix_')
    expect(subject.calculate_member_data_id_map(server, group_trigger)).to eq(expected_map_for_group_trigger)
  end
end
