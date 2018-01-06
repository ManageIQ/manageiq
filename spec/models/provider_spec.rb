describe Provider do
  let(:provider) { FactoryGirl.create(:provider) }

  describe "#verify_ssl" do
    context "when non set" do
      it "is default to verify ssl" do
        expect(provider.verify_ssl).to eq(OpenSSL::SSL::VERIFY_PEER)
        expect(provider).to be_verify_ssl
      end
    end

    context "when set to false" do
      before { provider.verify_ssl = false }

      it "is verify none" do
        expect(provider.verify_ssl).to eq(OpenSSL::SSL::VERIFY_NONE)
        expect(provider).not_to be_verify_ssl
      end
    end

    context "when set to true" do
      before { provider.verify_ssl = true }

      it "is verify peer" do
        expect(provider.verify_ssl).to eq(OpenSSL::SSL::VERIFY_PEER)
        expect(provider).to be_verify_ssl
      end
    end

    context "when set to verify none" do
      before { provider.verify_ssl = OpenSSL::SSL::VERIFY_NONE }

      it "is verify none" do
        expect(provider.verify_ssl).to eq(OpenSSL::SSL::VERIFY_NONE)
        expect(provider).not_to be_verify_ssl
      end
    end

    context "when set to verify peer" do
      before { provider.verify_ssl = OpenSSL::SSL::VERIFY_PEER }

      it "is verify peer" do
        expect(provider.verify_ssl).to eq(OpenSSL::SSL::VERIFY_PEER)
        expect(provider).to be_verify_ssl
      end
    end

    it "works with #update_attributes" do
      p = FactoryGirl.build(:provider_ansible_tower)
      p.update_attributes(:verify_ssl => 0)
      p.update_attributes(:verify_ssl => 1)

      expect(Endpoint.find(p.default_endpoint.id).verify_ssl).to eq(1)
    end
  end

  context "#tenant" do
    let(:tenant) { FactoryGirl.create(:tenant) }
    it "has a tenant" do
      provider = FactoryGirl.create(:provider, :tenant => tenant)
      expect(tenant.providers).to include(provider)
    end
  end

  context "#destroy_queue" do
    let!(:miq_server) { EvmSpecHelper.local_miq_server }
    it "queues destroy" do
      provider.destroy_queue
      expect(MiqQueue.find_by(:instance_id => provider.id)).to have_attributes(
        'method_name' => 'destroy',
        'class_name'  => provider.class.name,
      )
    end
  end

  context "#destroy" do
    it "destroys its managers and itself" do
      manager = FactoryGirl.create(:ext_management_system)
      provider.managers = [manager]
      expect(manager).to receive(:destroy)
      task = MiqTask.create(
        :name   => "Destroying #{self.class.name} with id: #{provider.id}",
        :state  => MiqTask::STATE_QUEUED,
        :status => MiqTask::STATUS_OK,
      )
      provider.destroy(task.id)
      task.reload
      expect(task).to have_attributes(
        'state'  => MiqTask::STATE_FINISHED,
        'status' => MiqTask::STATUS_OK
      )
    end
  end
end
