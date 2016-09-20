describe ManageIQ::Providers::Openstack::CloudManager::CloudVolumeSnapshot do
  let(:ems) { FactoryGirl.create(:ems_openstack) }
  let(:tenant) { FactoryGirl.create(:cloud_tenant_openstack, :ext_management_system => ems) }
  let(:cloud_volume) do
    FactoryGirl.create(:cloud_volume_openstack,
                       :ext_management_system => ems,
                       :name                  => 'volume',
                       :ems_ref               => 'volume_id',
                       :cloud_tenant          => tenant)
  end
  let(:cloud_volume_snapshot) do
    FactoryGirl.create(:cloud_volume_snapshot_openstack,
                       :ext_management_system => ems,
                       :name                  => 'test',
                       :ems_ref               => 'cloud_id',
                       :cloud_tenant          => tenant,
                       :cloud_volume          => cloud_volume,
                      )
  end

  let(:the_raw_snapshot) do
    double.tap do |snapshot|
      allow(snapshot).to receive(:id).and_return('cloud_id')
      allow(snapshot).to receive(:description).and_return('description for test')
      allow(snapshot).to receive(:status).and_return('available')
      allow(snapshot).to receive(:attributes).and_return({})
      allow(snapshot).to receive(:save).and_return(snapshot)
    end
  end

  let(:raw_snapshots) do
    double.tap do |snapshots|
      handle = double
      allow(handle).to receive(:snapshots).and_return(snapshots)
      allow(ems).to receive(:connect).with(hash_including(:service     => 'Volume',
                                                          :tenant_name => tenant.name)).and_return(handle)
      allow(ExtManagementSystem).to receive(:find).with(ems.id).and_return(ems)
      allow(CloudVolume).to receive(:find).with(cloud_volume.id).and_return(cloud_volume)
      # allow(cloud_volume).to receive(:try).with(:ext_management_system).and_return(ems)
      allow(snapshots).to receive(:get).with(cloud_volume_snapshot.ems_ref).and_return(the_raw_snapshot)
    end
  end

  before do
    raw_snapshots
  end

  describe 'snapshot actions' do
    context ".create_snapshot" do
      let(:the_new_snapshot) { double }
      let(:snapshot_options) { {:cloud_tenant => tenant, :name => "new_name"} }

      it 'creates a snapshot' do
        allow(the_new_snapshot).to receive("id").and_return('new_id')
        allow(the_new_snapshot).to receive(:name).and_return('new_name')
        allow(the_new_snapshot).to receive(:description).and_return('description for test')
        allow(the_new_snapshot).to receive("status").and_return('creating')
        allow(raw_snapshots).to receive(:create).and_return(the_new_snapshot)

        snapshot = ManageIQ::Providers::Openstack::CloudManager::CloudVolumeSnapshot
                   .create_snapshot(cloud_volume, snapshot_options)
        expect(snapshot.class).to        eq described_class
        expect(snapshot.name).to         eq 'new_name'
        expect(snapshot.ems_ref).to      eq 'new_id'
        expect(snapshot.status).to       eq 'creating'
        expect(snapshot.cloud_tenant).to eq tenant
      end
    end

    context "#update_snapshot" do
      it 'updates the snapshot' do
        expect(the_raw_snapshot).to receive(:update)
        cloud_volume_snapshot.update_snapshot({})
      end
    end

    context "#delete_snapshot" do
      it 'deletes the snapshot' do
        expect(the_raw_snapshot).to receive(:destroy)
        cloud_volume_snapshot.delete_snapshot({})
      end
    end
  end
end
