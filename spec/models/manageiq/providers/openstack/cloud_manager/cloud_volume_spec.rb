describe ManageIQ::Providers::Openstack::CloudManager::CloudVolume do
  let(:ems) { FactoryGirl.create(:ems_openstack) }
  let(:tenant) { FactoryGirl.create(:cloud_tenant_openstack, :ext_management_system => ems) }
  let(:cloud_volume) do
    FactoryGirl.create(:cloud_volume_openstack,
                       :ext_management_system => ems,
                       :name                  => 'test',
                       :ems_ref               => 'one_id',
                       :cloud_tenant          => tenant)
  end

  let(:the_raw_volume) do
    double.tap do |volume|
      allow(volume).to receive(:id).and_return('one_id')
      allow(volume).to receive(:status).and_return('available')
      allow(volume).to receive(:attributes).and_return({})
      allow(volume).to receive(:save).and_return(volume)
    end
  end

  let(:raw_volumes) do
    double.tap do |volumes|
      handle = double
      allow(handle).to receive(:volumes).and_return(volumes)
      allow(ExtManagementSystem).to receive(:find).with(ems.id).and_return(ems)
      allow(ems).to receive(:connect).with(hash_including(:service     => 'Volume',
                                                          :tenant_name => tenant.name)).and_return(handle)
      allow(volumes).to receive(:get).with(cloud_volume.ems_ref).and_return(the_raw_volume)
    end
  end

  before do
    raw_volumes
  end

  describe 'volume actions' do
    context ".create_volume" do
      let(:the_new_volume) { double }
      let(:volume_options) { {:cloud_tenant => tenant, :name => "new_name", :size => 2} }

      before do
        allow(raw_volumes).to receive(:new).and_return(the_new_volume)
      end

      it 'creates a volume' do
        allow(the_new_volume).to receive("id").and_return('new_id')
        allow(the_new_volume).to receive("status").and_return('creating')
        expect(the_new_volume).to receive(:save).and_return(the_new_volume)

        volume = CloudVolume.create_volume(ems.id, volume_options)
        expect(volume.class).to        eq described_class
        expect(volume.name).to         eq 'new_name'
        expect(volume.ems_ref).to      eq 'new_id'
        expect(volume.status).to       eq 'creating'
        expect(volume.cloud_tenant).to eq tenant
      end

      it "raises an error when the ems is missing" do
        expect { CloudVolume.create_volume(nil) }.to raise_error(ArgumentError)
      end

      it "validates the volume create operation" do
        validation = CloudVolume.validate_create_volume(ems)
        expect(validation[:available]).to be true
      end

      it "validates the volume create operation when ems is missing" do
        validation = CloudVolume.validate_create_volume(nil)
        expect(validation[:available]).to be false
      end

      it 'catches errors from provider' do
        expect(the_new_volume).to receive(:save).and_raise('bad request')

        expect { CloudVolume.create_volume(ems.id, volume_options) }.to raise_error(MiqException::MiqVolumeCreateError)
      end
    end

    context "#update_volume" do
      it 'updates the volume' do
        expect(the_raw_volume).to receive(:save)
        cloud_volume.update_volume({})
      end

      it "validates the volume update operation" do
        validation = cloud_volume.validate_update_volume
        expect(validation[:available]).to be true
      end

      it "validates the volume update operation when ems is missing" do
        expect(cloud_volume).to receive(:ext_management_system).and_return(nil)
        validation = cloud_volume.validate_update_volume
        expect(validation[:available]).to be false
      end

      it 'catches errors from provider' do
        expect(the_raw_volume).to receive(:save).and_raise('bad request')
        expect { cloud_volume.update_volume({}) }.to raise_error(MiqException::MiqVolumeUpdateError)
      end
    end

    context "#delete_volume" do
      it "validates the volume delete operation when status is in-use" do
        expect(the_raw_volume).to receive(:status).and_return("in-use")
        validation = cloud_volume.validate_delete_volume
        expect(validation[:available]).to be false
      end

      it "validates the volume delete operation when status is available" do
        expect(the_raw_volume).to receive(:status).and_return("available")
        validation = cloud_volume.validate_delete_volume
        expect(validation[:available]).to be true
      end

      it "validates the volume delete operation when status is error" do
        expect(the_raw_volume).to receive(:status).and_return("error")
        validation = cloud_volume.validate_delete_volume
        expect(validation[:available]).to be true
      end

      it "validates the volume delete operation when ems is missing" do
        expect(cloud_volume).to receive(:ext_management_system).and_return(nil)
        validation = cloud_volume.validate_delete_volume
        expect(validation[:available]).to be false
      end

      it 'updates the volume' do
        expect(the_raw_volume).to receive(:destroy)
        cloud_volume.delete_volume
      end

      it 'catches errors from provider' do
        expect(the_raw_volume).to receive(:destroy).and_raise('bad request')
        expect { cloud_volume.delete_volume }.to raise_error(MiqException::MiqVolumeDeleteError)
      end
    end
  end
end
