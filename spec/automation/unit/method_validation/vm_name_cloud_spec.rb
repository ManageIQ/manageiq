require Rails.root.join('db/fixtures/ae_datastore/ManageIQ/Cloud/VM/Provisioning/Naming.class/__methods__/vmname').to_s

describe VmName do
  let(:provision) { MiqProvision.new }
  let(:root_object) { Spec::Support::MiqAeMockObject.new.tap { |ro| ro["miq_provision"] = provision } }
  let(:service) { Spec::Support::MiqAeMockService.new(root_object).tap { |s| s.object = {'vm_prefix' => "abc"} } }
  let(:classification) { FactoryGirl.create(:classification, :tag => tag, :name => "environment") }
  let(:classification2) do
    FactoryGirl.create(:classification,
                       :tag    => tag2,
                       :parent => classification,
                       :name   => "prod")
  end
  let(:tag) { FactoryGirl.create(:tag, :name => "/managed/environment") }
  let(:tag2) { FactoryGirl.create(:tag, :name => "/managed/environment/production") }

  context "#main" do
    it "no vm name from dialog" do
      provision.update_attributes(:options => {:number_of_vms => 200})

      described_class.new(service).main

      expect(service.object['vmname']).to eq('abc$n{3}')
    end

    it "vm name from dialog" do
      provision.update_attributes(:options => {:number_of_vms => 200, :vm_name => "drew"})

      described_class.new(service).main

      expect(service.object['vmname']).to eq('drew$n{3}')
    end

    it "use model and environment tag" do
      provision.update_attributes(:options => {:number_of_vms => 200, :vm_tags => [classification2.id]})

      described_class.new(service).main

      expect(service.object['vmname']).to eq('abcpro$n{3}')
    end

    it "provisions single vm" do
      provision.update_attributes(:options => {:number_of_vms => 1})

      described_class.new(service).main

      expect(service.object['vmname']).to eq('abc$n{3}')
    end
  end
end
