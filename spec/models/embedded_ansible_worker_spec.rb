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

    let(:org_resource)         { double("AnsibleOrgResource", :id => 12) }
    let(:cred_resource)        { double("AnsibleCredResource", :id => 13) }
    let(:inv_resource)         { double("AnsibleInvResource", :id => 14) }
    let(:host_resource)        { double("AnsibleHostResource", :id => 15) }
    let(:job_templ_resource)   { double("AnsibleJobTemplResource", :id => 16) }
    let(:proj_resource)        { double("AnsibleProjResource", :id => 17) }

    context "with existing data" do
      let(:org_collection)       { double("AnsibleOrgCollection", :all => [org_resource]) }
      let(:cred_collection)      { double("AnsibleCredCollection", :all => [cred_resource]) }
      let(:inv_collection)       { double("AnsibleInvCollection", :all => [inv_resource]) }
      let(:host_collection)      { double("AnsibleHostCollection", :all => [host_resource]) }
      let(:job_templ_collection) { double("AnsibleJobTemplCollection", :all => [job_templ_resource]) }
      let(:proj_collection)      { double("AnsibleProjCollection", :all => [proj_resource]) }

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
        it "sets the default organization to the existing one" do
          subject.ensure_organization(provider, api_connection)
          expect(provider.default_organization).to eq(12)
        end
      end

      describe "#ensure_credential" do
        it "sets the default credential to the existing one" do
          subject.ensure_credential(provider, api_connection)
          expect(provider.default_credential).to eq(13)
        end
      end

      describe "#ensure_inventory" do
        it "sets the default inventory to the existing one" do
          subject.ensure_inventory(provider, api_connection)
          expect(provider.default_inventory).to eq(14)
        end
      end

      describe "#ensure_host" do
        it "sets the default host to the existing one" do
          subject.ensure_host(provider, api_connection)
          expect(provider.default_host).to eq(15)
        end
      end
    end

    context "with no existing data" do
      let(:org_collection)       { double("AnsibleOrgCollection", :all => []) }
      let(:cred_collection)      { double("AnsibleCredCollection", :all => []) }
      let(:inv_collection)       { double("AnsibleInvCollection", :all => []) }
      let(:host_collection)      { double("AnsibleHostCollection", :all => []) }
      let(:job_templ_collection) { double("AnsibleJobTemplCollection", :all => []) }
      let(:proj_collection)      { double("AnsibleProjCollection", :all => []) }

      describe "#ensure_initial_objects" do
        it "creates the expected objects" do
          expect(org_collection).to receive(:create!).and_return(org_resource)
          expect(cred_collection).to receive(:create!).and_return(cred_resource)
          expect(inv_collection).to receive(:create!).and_return(inv_resource)
          expect(host_collection).to receive(:create!).and_return(host_resource)

          subject.ensure_initial_objects(provider, api_connection)
        end
      end

      describe "#ensure_organization" do
        it "sets the provider default organization" do
          expect(org_collection).to receive(:create!).with(
            :name        => "EVM",
            :description => "EVM Default Organization"
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
            :name         => "EVM Default Credential",
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

        it "creates the organization if one doesn't exist" do
          expect(org_collection).to receive(:create!).with(
            :name        => "EVM",
            :description => "EVM Default Organization"
          ).and_return(org_resource)

          expect(cred_collection).to receive(:create!).with(
            :name         => "EVM Default Credential",
            :kind         => "ssh",
            :organization => 12
          ).and_return(cred_resource)

          subject.ensure_credential(provider, api_connection)
          expect(provider.default_credential).to eq(13)
          expect(provider.default_organization).to eq(12)
        end
      end

      describe "#ensure_inventory" do
        it "sets the provider default inventory" do
          provider.default_organization = 123
          expect(inv_collection).to receive(:create!).with(
            :name         => "EVM Default Inventory",
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

        it "creates the organization if one doesn't exist" do
          expect(org_collection).to receive(:create!).with(
            :name        => "EVM",
            :description => "EVM Default Organization"
          ).and_return(org_resource)

          expect(inv_collection).to receive(:create!).with(
            :name         => "EVM Default Inventory",
            :organization => 12
          ).and_return(inv_resource)

          subject.ensure_inventory(provider, api_connection)
          expect(provider.default_inventory).to eq(14)
          expect(provider.default_organization).to eq(12)
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

        it "creates the inventory if one doesn't exist" do
          provider.default_organization = 12
          expect(inv_collection).to receive(:create!).with(
            :name         => "EVM Default Inventory",
            :organization => 12
          ).and_return(inv_resource)

          expect(host_collection).to receive(:create!).with(
            :name      => "localhost",
            :inventory => 14,
            :variables => "---\nansible_connection: local\n"
          ).and_return(host_resource)

          subject.ensure_host(provider, api_connection)
          expect(provider.default_host).to eq(15)
          expect(provider.default_inventory).to eq(14)
        end
      end
    end
  end
end
