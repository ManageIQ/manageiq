describe EmbeddedAnsibleWorker do
  subject { FactoryGirl.create(:embedded_ansible_worker) }

  context "ObjectManagement concern" do
    let(:provider)       { FactoryGirl.create(:provider_embedded_ansible) }
    let(:api_connection) { double("AnsibleAPIConnection", :api => tower_api) }
    let(:tower_api) do
      methods = {
        :organizations => org_collection,
        :credentials   => cred_collection,
        :inventories   => inv_collection,
        :hosts         => host_collection,
        :job_templates => job_templ_collection,
        :projects      => proj_collection

      }
      double("TowerAPI", methods)
    end

    let(:org_collection)       { double("AnsibleOrgCollection", :all => [org_resource]) }
    let(:cred_collection)      { double("AnsibleCredCollection", :all => [cred_resource]) }
    let(:inv_collection)       { double("AnsibleInvCollection", :all => [inv_resource]) }
    let(:host_collection)      { double("AnsibleHostCollection", :all => [host_resource]) }
    let(:job_templ_collection) { double("AnsibleJobTemplCollection", :all => [job_templ_resource]) }
    let(:proj_collection)      { double("AnsibleProjCollection", :all => [proj_resource]) }

    let(:org_resource)         { double("AnsibleOrgResource", :id => 12) }
    let(:cred_resource)        { double("AnsibleCredResource", :id => 13) }
    let(:inv_resource)         { double("AnsibleInvResource", :id => 14) }
    let(:host_resource)        { double("AnsibleHostResource", :id => 15) }
    let(:job_templ_resource)   { double("AnsibleJobTemplResource", :id => 16) }
    let(:proj_resource)        { double("AnsibleProjResource", :id => 17) }

    describe "#ensure_initial_objects" do
      it "creates the expected objects" do
        expect(org_collection).to receive(:create!).and_return(org_resource)
        expect(cred_collection).to receive(:create!).and_return(cred_resource)
        expect(inv_collection).to receive(:create!).and_return(inv_resource)
        expect(host_collection).to receive(:create!).and_return(host_resource)

        subject.ensure_initial_objects(provider, api_connection)
      end
    end

    describe "#remove_demo_data" do
      it "removes the existing data" do
        expect(org_resource).to receive(:destroy!)
        expect(cred_resource).to receive(:destroy!)
        expect(inv_resource).to receive(:destroy!)
        expect(job_templ_resource).to receive(:destroy!)
        expect(proj_resource).to receive(:destroy!)

        subject.remove_demo_data(api_connection)
      end
    end

    describe "#ensure_organization" do
      it "sets the provider default organization" do
        expect(org_collection).to receive(:create!).with(
          :name        => "ManageIQ",
          :description => "ManageIQ Default Organization"
        ).and_return(org_resource)

        subject.ensure_organization(provider, api_connection)
        expect(provider.default_organization).to eq(12)
      end

      it "doesn't recreate the organization if one is already set" do
        provider.default_organization = 1
        expect(org_collection).not_to receive(:create!)

        subject.ensure_organization(provider, api_connection)
      end
    end

    describe "#ensure_credential" do
      it "sets the provider default credential" do
        provider.default_organization = 123
        expect(cred_collection).to receive(:create!).with(
          :name         => "ManageIQ Default Credential",
          :kind         => "ssh",
          :organization => 123
        ).and_return(cred_resource)

        subject.ensure_credential(provider, api_connection)
        expect(provider.default_credential).to eq(13)
      end

      it "doesn't recreate the credential if one is already set" do
        provider.default_credential = 2
        expect(cred_collection).not_to receive(:create!)

        subject.ensure_credential(provider, api_connection)
      end
    end

    describe "#ensure_inventory" do
      it "sets the provider default inventory" do
        provider.default_organization = 123
        expect(inv_collection).to receive(:create!).with(
          :name         => "ManageIQ Default Inventory",
          :organization => 123
        ).and_return(inv_resource)

        subject.ensure_inventory(provider, api_connection)
        expect(provider.default_inventory).to eq(14)
      end

      it "doesn't recreate the inventory if one is already set" do
        provider.default_inventory = 3
        expect(inv_collection).not_to receive(:create!)

        subject.ensure_inventory(provider, api_connection)
      end
    end

    describe "#ensure_host" do
      it "sets the provider default host" do
        provider.default_inventory = 234
        expect(host_collection).to receive(:create!).with(
          :name      => "localhost",
          :inventory => 234,
          :variables => "---\nansible_connection: local\n"
        ).and_return(host_resource)

        subject.ensure_host(provider, api_connection)
        expect(provider.default_host).to eq(15)
      end

      it "doesn't recreate the host if one is already set" do
        provider.default_host = 1
        expect(host_collection).not_to receive(:create!)

        subject.ensure_host(provider, api_connection)
      end
    end

    describe "#start_monitor_thread" do
      let(:pool) { double("ConnectionPool") }

      before do
        allow(Thread).to receive(:new).and_return({})
        allow(described_class::Runner).to receive(:start_worker)
      end

      it "sets worker class and id in thread object" do
        thread = subject.start_monitor_thread
        expect(thread[:worker_class]).to eq subject.class.name
        expect(thread[:worker_id]).to    eq subject.id
      end

      it "adds a connection to the pool if there is only one" do
        allow(ActiveRecord::Base).to receive(:connection_pool).and_return(pool)

        expect(pool).to receive(:instance_variable_get).with(:@size).and_return(1)
        expect(pool).to receive(:instance_variable_set).with(:@size, 2)
        subject.start_monitor_thread
      end
    end

    describe "#find_worker_thread_object" do
      it "returns the the thread matching the class and id of the worker" do
        worker1 = {:worker_id => subject.id + 1, :worker_class => "SomeOtherWorker"}
        worker2 = {:worker_id => subject.id,     :worker_class => subject.class.name}
        allow(Thread).to receive(:list).and_return([worker1, worker2])
        expect(subject.find_worker_thread_object).to eq(worker2)
      end

      it "returns nil if nothing matches" do
        worker1 = {:worker_id => subject.id + 1, :worker_class => subject.class.name}
        worker2 = {:worker_id => subject.id + 2, :worker_class => subject.class.name}
        allow(Thread).to receive(:list).and_return([worker1, worker2])
        expect(subject.find_worker_thread_object).to be_nil
      end
    end

    describe "#kill" do
      it "exits the monitoring thread and destroys the worker row" do
        thread_double = double
        expect(thread_double).to receive(:exit)
        allow(subject).to receive(:find_worker_thread_object).and_return(thread_double)
        subject.kill
        expect { subject.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "destroys the worker row but refuses to kill the main thread" do
        allow(subject).to receive(:find_worker_thread_object).and_return(Thread.main)
        subject.kill
        expect { subject.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "destroys the worker row if the monitor thread is not found" do
        allow(subject).to receive(:find_worker_thread_object).and_return(nil)
        subject.kill
        expect { subject.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
