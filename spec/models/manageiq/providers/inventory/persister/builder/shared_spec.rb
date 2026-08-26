require "inventory_refresh"

RSpec.describe ManageIQ::Providers::Inventory::Persister::Builder::Shared do
  let(:ems) { FactoryBot.create(:ems_infra) }
  let(:persister_class) do
    Class.new(ManageIQ::Providers::Inventory::Persister) do
      def initialize_inventory_collections
      end
    end
  end
  let(:persister) { persister_class.new(ems, InventoryRefresh::TargetCollection.new(:manager => ems)) }

  describe "#relationship_save_block" do
    let(:relationship_type) { :ems_metadata }
    let(:parent_type) { "ResourcePool" }

    let!(:resource_pool1) { FactoryBot.create(:resource_pool, :ems_id => ems.id) }
    let!(:resource_pool2) { FactoryBot.create(:resource_pool, :ems_id => ems.id) }
    let!(:vm1) { FactoryBot.create(:vm_vmware, :ems_id => ems.id) }
    let!(:vm2) { FactoryBot.create(:vm_vmware, :ems_id => ems.id) }
    let!(:vm3) { FactoryBot.create(:vm_vmware, :ems_id => ems.id) }
    let!(:vm4) { FactoryBot.create(:vm_vmware, :ems_id => ems.id) }

    let(:builder) do
      Class.new do
        include ManageIQ::Providers::Inventory::Persister::Builder::Shared

        attr_accessor :persister_class, :parent

        def initialize(persister_class, parent)
          @persister_class = persister_class
          @parent = parent
        end
      end.new(persister_class, ems)
    end

    let(:save_block) do
      builder.send(:relationship_save_block,
                   :relationship_key  => :resource_pool,
                   :relationship_type => relationship_type,
                   :parent_type       => parent_type)
    end

    before do
      vm1.with_relationship_type(relationship_type) { vm1.parent = resource_pool1 }
      vm2.with_relationship_type(relationship_type) { vm2.parent = resource_pool1 }
    end

    context "when object moves from parent to nil (removal)" do
      it "removes the child from the parent" do
        inventory_collection = double("InventoryCollection")

        vm1_obj = double("InventoryObject", :id => vm1.id, :data => {:resource_pool => nil})
        vm1_collection = double("Collection", :model_class => Vm, :data => [vm1_obj])

        allow(inventory_collection).to receive(:dependency_attributes).and_return([[:vms, [vm1_collection]]])

        save_block.call(ems, inventory_collection)

        vm1.reload
        expect(vm1.with_relationship_type(relationship_type) { vm1.parent }).to be_nil

        resource_pool1.reload
        expect(resource_pool1.with_relationship_type(relationship_type) { resource_pool1.children }).not_to include(vm1)
      end
    end

    context "when object moves from nil to parent (addition)" do
      it "adds the child to the parent" do
        inventory_collection = double("InventoryCollection")

        parent_ref = double("ParentRef")
        allow(parent_ref).to receive(:load).and_return(
          double("ParentInventoryObject",
                 :id                   => resource_pool1.id,
                 :inventory_collection => double("ParentCollection", :model_class => ResourcePool))
        )

        vm3_obj = double("InventoryObject", :id => vm3.id, :data => {:resource_pool => parent_ref})
        vm3_collection = double("Collection", :model_class => Vm, :data => [vm3_obj])

        allow(inventory_collection).to receive(:dependency_attributes).and_return([[:vms, [vm3_collection]]])

        save_block.call(ems, inventory_collection)

        vm3.reload
        expect(vm3.with_relationship_type(relationship_type) { vm3.parent }).to eq(resource_pool1)

        resource_pool1.reload
        expect(resource_pool1.with_relationship_type(relationship_type) { resource_pool1.children }).to include(vm3)
      end
    end

    context "when object changes from one parent to another" do
      it "moves the child from old parent to new parent" do
        inventory_collection = double("InventoryCollection")

        parent_ref = double("ParentRef")
        allow(parent_ref).to receive(:load).and_return(
          double("ParentInventoryObject",
                 :id                   => resource_pool2.id,
                 :inventory_collection => double("ParentCollection", :model_class => ResourcePool))
        )

        vm1_obj = double("InventoryObject", :id => vm1.id, :data => {:resource_pool => parent_ref})
        vm1_collection = double("Collection", :model_class => Vm, :data => [vm1_obj])

        allow(inventory_collection).to receive(:dependency_attributes).and_return([[:vms, [vm1_collection]]])

        save_block.call(ems, inventory_collection)

        vm1.reload
        expect(vm1.with_relationship_type(relationship_type) { vm1.parent }).to eq(resource_pool2)

        resource_pool1.reload
        expect(resource_pool1.with_relationship_type(relationship_type) { resource_pool1.children }).not_to include(vm1)

        resource_pool2.reload
        expect(resource_pool2.with_relationship_type(relationship_type) { resource_pool2.children }).to include(vm1)
      end
    end

    context "when object stays with nil parent (no change)" do
      it "does not create any relationships" do
        inventory_collection = double("InventoryCollection")

        vm4_obj = double("InventoryObject", :id => vm4.id, :data => {:resource_pool => nil})
        vm4_collection = double("Collection", :model_class => Vm, :data => [vm4_obj])

        allow(inventory_collection).to receive(:dependency_attributes).and_return([[:vms, [vm4_collection]]])

        expect { save_block.call(ems, inventory_collection) }.not_to raise_error

        vm4.reload
        expect(vm4.with_relationship_type(relationship_type) { vm4.parent }).to be_nil
      end
    end

    context "when object keeps the same parent (no change)" do
      it "does not modify the relationship" do
        inventory_collection = double("InventoryCollection")

        parent_ref = double("ParentRef")
        allow(parent_ref).to receive(:load).and_return(
          double("ParentInventoryObject",
                 :id                   => resource_pool1.id,
                 :inventory_collection => double("ParentCollection", :model_class => ResourcePool))
        )

        vm1_obj = double("InventoryObject", :id => vm1.id, :data => {:resource_pool => parent_ref})
        vm1_collection = double("Collection", :model_class => Vm, :data => [vm1_obj])

        allow(inventory_collection).to receive(:dependency_attributes).and_return([[:vms, [vm1_collection]]])

        expect(resource_pool1).not_to receive(:remove_children)
        expect(resource_pool1).not_to receive(:add_children)

        save_block.call(ems, inventory_collection)

        vm1.reload
        expect(vm1.with_relationship_type(relationship_type) { vm1.parent }).to eq(resource_pool1)
      end
    end

    context "when processing multiple objects with mixed scenarios" do
      it "handles all scenarios correctly in a single transaction" do
        inventory_collection = double("InventoryCollection")

        # vm1: changes from resource_pool1 to resource_pool2
        parent_ref1 = double("ParentRef1")
        allow(parent_ref1).to receive(:load).and_return(
          double("ParentInventoryObject",
                 :id                   => resource_pool2.id,
                 :inventory_collection => double("ParentCollection", :model_class => ResourcePool))
        )
        vm1_obj = double("InventoryObject", :id => vm1.id, :data => {:resource_pool => parent_ref1})

        # vm2: moves from resource_pool1 to nil
        vm2_obj = double("InventoryObject", :id => vm2.id, :data => {:resource_pool => nil})

        # vm3: moves from nil to resource_pool1
        parent_ref3 = double("ParentRef3")
        allow(parent_ref3).to receive(:load).and_return(
          double("ParentInventoryObject",
                 :id                   => resource_pool1.id,
                 :inventory_collection => double("ParentCollection", :model_class => ResourcePool))
        )
        vm3_obj = double("InventoryObject", :id => vm3.id, :data => {:resource_pool => parent_ref3})

        # vm4: stays at nil
        vm4_obj = double("InventoryObject", :id => vm4.id, :data => {:resource_pool => nil})

        vm_collection = double("Collection", :model_class => Vm, :data => [vm1_obj, vm2_obj, vm3_obj, vm4_obj])

        allow(inventory_collection).to receive(:dependency_attributes).and_return([[:vms, [vm_collection]]])

        save_block.call(ems, inventory_collection)

        vm1.reload
        vm2.reload
        vm3.reload
        vm4.reload
        resource_pool1.reload
        resource_pool2.reload

        expect(vm1.with_relationship_type(relationship_type) { vm1.parent }).to eq(resource_pool2)
        expect(vm2.with_relationship_type(relationship_type) { vm2.parent }).to be_nil
        expect(vm3.with_relationship_type(relationship_type) { vm3.parent }).to eq(resource_pool1)
        expect(vm4.with_relationship_type(relationship_type) { vm4.parent }).to be_nil

        expect(resource_pool1.with_relationship_type(relationship_type) { resource_pool1.children }).to contain_exactly(vm3)
        expect(resource_pool2.with_relationship_type(relationship_type) { resource_pool2.children }).to contain_exactly(vm1)
      end
    end
  end
end
