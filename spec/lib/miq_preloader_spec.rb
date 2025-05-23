RSpec.describe MiqPreloader do
  # implied vms (simple association)
  let(:ems) { FactoryBot.create(:ems_infra).tap { |ems| FactoryBot.create_list(:vm, 2, :ext_management_system => ems) } }
  let(:zone) { FactoryBot.create(:zone) }

  # implied container_nodes (through association)
  let(:image) do
    FactoryBot.create(:container_image).tap do |image|
      FactoryBot.create(
        :container,
        :container_image => image,
        :container_group => FactoryBot.create(:container_group, :container_node => FactoryBot.create(:container_node))
      )
    end
  end

  describe ".preload" do
    it "preloads once from an object" do
      ems = FactoryBot.create(:ems_infra)
      expect(ems.vms).not_to be_loaded
      expect { preload(ems, :vms) }.to make_database_queries(:count => 1)

      expect(ems.vms).to be_loaded
      expect { preload(ems, :vms) }.not_to make_database_queries
      expect { ems.vms.size }.not_to make_database_queries
    end

    it "preloads an array" do
      emses = FactoryBot.create_list(:ems_infra, 2)
      expect { preload(emses, :vms) }.to make_database_queries(:count => 1)

      expect(emses.first.vms).to be_loaded
      expect { emses.first.vms.size }.not_to make_database_queries
    end

    it "preloads a relation (record is a relation)" do
      FactoryBot.create_list(:vm, 2, :ext_management_system => FactoryBot.create(:ems_infra))
      emses = ExtManagementSystem.all
      expect { preload(emses, :vms) }.to make_database_queries(:count => 2)

      expect { expect(emses.first.vms.size).to eq(2) }.not_to make_database_queries
    end

    it "preloads with a relation (records is a relation)" do
      ems = FactoryBot.create(:ems_infra)
      FactoryBot.create_list(:vm, 2, :ext_management_system => ems)
      emses = ExtManagementSystem.all.load
      vms   = Vm.where(:ems_id => emses.select(:id))

      expect { preload(emses, :vms, vms) }.to make_database_queries(:count => 1)
      expect { expect(emses.first.vms.size).to eq(2) }.not_to make_database_queries
    end

    # original behavior - not calling our code
    it "preloads with an unloaded simple relation" do
      vms = Vm.where(:ems_id => ems.id)
      vms2 = vms.order(:id).load # preloaded vms to be used in tests

      expect { preload(ems, :vms, vms) }.to make_database_queries(:count => 1)

      expect { preload(ems, :vms, vms) }.not_to make_database_queries
      expect { expect(ems.vms).to match_array(vms2) }.not_to make_database_queries

      expect { expect(vms.first.ext_management_system).to eq(ems) }.to make_database_queries(:count => 2)
    end

    it "preloads with a loaded relation (records is a relation)" do
      ems
      emses = ExtManagementSystem.all.load
      vms   = Vm.where(:ems_id => emses.select(:id)).load

      expect { preload(emses, :vms, vms) }.to make_database_queries(:count => 1)

      expect { preload(emses, :vms, vms) }.not_to make_database_queries
      expect { expect(emses.first.vms.size).to eq(2) }.not_to make_database_queries

      # TODO: With rails 7, the query count below increased by 1.
      expect { expect(vms.first.ext_management_system).to eq(ems) }.to make_database_queries(:count => 1)
    end

    it "preloads singular association with a loaded relation (records is a relation)" do
      emses = ExtManagementSystem.select(:id).where(:id => ems.id).load
      vms = Vm.where(:ems_id => emses.select(:id)).load
      preload(vms, :ext_management_system, emses)

      expect { preload(vms, :ext_management_system, emses) }.not_to make_database_queries
      expect { expect(vms.size).to eq(2) }.not_to make_database_queries
      expect { expect(vms.first.ext_management_system).to eq(emses.first) }.not_to make_database_queries
    end

    it "preloads a through with a loaded scope" do
      image
      nodes = ContainerNode.all.load

      # NOTE: it currently ignores the locally loaded records
      # TODO: not_to make_database_queries
      expect { preload(image, :container_nodes, nodes) }.to make_database_queries(:count => 3)
      expect { preload(image, :container_nodes, nodes) }.not_to make_database_queries
      expect { expect(image.container_nodes).to eq(nodes) }.not_to make_database_queries
      # TODO: not_to make_database_queries
      expect { expect(nodes.first.container_images).to eq([image]) }.to make_database_queries(:count => 1)
    end

    it "preloads association array" do
      host = FactoryBot.create(:host_vmware) # infra
      FactoryBot.create_list(:vm, 2, :ext_management_system => FactoryBot.create(:ems_infra, :zone => zone), :host => host)
      emses = ExtManagementSystem.all

      # 4: ems, zones, vms, hosts
      expect { preload(emses, [:zone, :vms => :host]) }.to make_database_queries(:count => 4)

      expect { expect(emses.first.vms.size).to eq(2) }.not_to make_database_queries
      expect { expect(emses.first.vms.first.host).to eq(host) }.not_to make_database_queries
      expect { expect(emses.first.zone).to eq(zone) }.not_to make_database_queries
    end

    def preload(*args, **kwargs)
      MiqPreloader.preload(*args, **kwargs)
    end
  end

  describe ".preload_from_array" do
    it "preloads a loaded simple relation" do
      vms = Vm.where(:ems_id => ems.id).load

      expect { preload_from_array(ems, :vms, vms) }.not_to make_database_queries
      expect { preload_from_array(ems, :vms, vms) }.not_to make_database_queries
      expect { expect(ems.vms.size).to eq(2) }.not_to make_database_queries
      expect { expect(vms.first.ext_management_system).to eq(ems) }.not_to make_database_queries
    end

    it "preloads an unloaded simple relation" do
      vms = Vm.where(:ems_id => ems.id)
      vms2 = vms.order(:id).to_a # preloaded vms to be used in tests

      expect { preload_from_array(ems, :vms, vms) }.to make_database_queries(:count => 1)
      expect { preload_from_array(ems, :vms, vms) }.not_to make_database_queries
      expect { expect(ems.vms).to match_array(vms2) }.not_to make_database_queries
      expect { expect(vms.first.ext_management_system).to eq(ems) }.not_to make_database_queries
    end

    it "preloads an array of a simple relation" do
      vms = Vm.where(:ems_id => ems.id).to_a

      expect { preload_from_array(ems, :vms, vms) }.not_to make_database_queries
      expect { preload_from_array(ems, :vms, vms) }.not_to make_database_queries
      expect { expect(ems.vms.size).to eq(2) }.not_to make_database_queries
      expect { expect(vms.first.ext_management_system).to eq(ems) }.not_to make_database_queries
    end

    it "preloads a loaded through relation" do
      image
      nodes = ContainerNode.all.load

      expect { preload_from_array(image, :container_nodes, nodes) }.not_to make_database_queries
      expect { preload_from_array(image, :container_nodes, nodes) }.not_to make_database_queries
      expect { expect(image.container_nodes).to eq(nodes) }.not_to make_database_queries
      # TODO: can we get this to 0 queries?
      expect { expect(nodes.first.container_images).to eq([image]) }.to make_database_queries(:count => 1)
    end

    it "preloads an array of a through relation" do
      image
      nodes = ContainerNode.all.to_a

      expect { preload_from_array(image, :container_nodes, nodes) }.not_to make_database_queries
      expect { preload_from_array(image, :container_nodes, nodes) }.not_to make_database_queries
      expect { expect(image.container_nodes).to eq(nodes) }.not_to make_database_queries
      # TODO: can we get this to 0 queries?
      expect { expect(nodes.first.container_images).to eq([image]) }.to make_database_queries(:count => 1)
    end

    def preload_from_array(record, relation, values)
      MiqPreloader.preload_from_array(record, relation, values)
    end
  end

  describe ".preload_and_map" do
    it "preloads from an object" do
      ems = FactoryBot.create(:ems_infra)
      FactoryBot.create_list(:vm, 2, :ext_management_system => ems)
      vms = nil
      expect { vms = preload_and_map(ems, :vms) }.to make_database_queries(:count => 1)

      expect { expect(vms.size).to eq(2) }.not_to make_database_queries
    end

    it "preloads from an association" do
      ems = FactoryBot.create(:ems_infra)
      FactoryBot.create_list(:vm, 2, :ext_management_system => ems)

      emses = ExtManagementSystem.all
      expect { preload_and_map(emses, :vms) }.to make_database_queries(:count => 2)
    end

    def preload_and_map(*args)
      MiqPreloader.preload_and_map(*args)
    end
  end

  describe ".preload_and_scope" do
    it "preloads (object).has_many" do
      ems = FactoryBot.create(:ems_infra)
      FactoryBot.create_list(:vm, 2, :ext_management_system => ems)

      vms = nil
      expect { vms = preload_and_scope(ems, :vms) }.not_to make_database_queries
      expect { expect(vms.count).to eq(2) }.to make_database_queries(:count => 1)
    end

    it "preloads (object.all).has_many" do
      FactoryBot.create_list(:vm, 2, :ext_management_system => FactoryBot.create(:ems_infra))
      FactoryBot.create(:template, :ext_management_system => FactoryBot.create(:ems_infra))

      vms = nil
      expect { vms = preload_and_scope(ExtManagementSystem.all, :vms_and_templates) }.not_to make_database_queries
      expect { expect(vms.count).to eq(3) }.to make_database_queries(:count => 1)
    end

    it "respects scopes (object.all).has_many {with scope}" do
      FactoryBot.create_list(:vm, 2, :ext_management_system => FactoryBot.create(:ems_infra))
      FactoryBot.create(:template, :ext_management_system => FactoryBot.create(:ems_infra))

      expect { expect(preload_and_scope(ExtManagementSystem.all, :vms).count).to eq(2) }.to make_database_queries(:count => 1)
    end

    it "preloads (object.all).has_many.belongs_to" do
      ems = FactoryBot.create(:ems_infra)
      FactoryBot.create_list(:vm, 2,
                             :ext_management_system => ems,
                             :host                  => FactoryBot.create(:host, :ext_management_system => ems))
      FactoryBot.create(:vm, :ext_management_system => ems,
                             :host                  => FactoryBot.create(:host, :ext_management_system => ems))

      hosts = nil
      vms = nil
      expect { vms = preload_and_scope(ExtManagementSystem.all, :vms_and_templates) }.not_to make_database_queries
      expect { hosts = preload_and_scope(vms, :host) }.not_to make_database_queries
      expect { expect(hosts.count).to eq(2) }.to make_database_queries(:count => 1)
    end

    it "preloads (object.all).belongs_to.has_many" do
      ems = FactoryBot.create(:ems_infra)
      host = FactoryBot.create(:host, :ext_management_system => ems)
      FactoryBot.create_list(:vm, 2, :ext_management_system => ems, :host => host)
      host = FactoryBot.create(:host, :ext_management_system => ems)
      FactoryBot.create(:vm, :ext_management_system => ems, :host => host)

      emses = nil
      vms = nil
      expect { emses = preload_and_scope(Host.all, :ext_management_system) }.not_to make_database_queries
      expect { vms = preload_and_scope(emses, :vms) }.not_to make_database_queries
      expect { expect(vms.count).to eq(3) }.to make_database_queries(:count => 1)
    end

    def preload_and_scope(*args)
      MiqPreloader.preload_and_scope(*args)
    end
  end
end
