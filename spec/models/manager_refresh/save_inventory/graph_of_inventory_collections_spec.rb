require_relative 'spec_helper'
require_relative 'spec_parsed_data'

describe ManagerRefresh::SaveInventory do
  include SpecHelper
  include SpecParsedData

  ######################################################################################################################
  #
  # Testing SaveInventory for general graph of the InventoryCollection dependencies, testing that relations
  # are saved correctly for a testing set of InventoryCollections whose dependencies look like:
  #
  # 1. Example, cycle is stack -> stack
  #
  # edge Stack -> Stack is created by (:parent => @data[:orchestration_stacks].lazy_find(stack_ems_ref)) meaning Stack
  #   depends on Stack through :parent attribute
  #
  # edge Resource -> Stack is created by (:stack => @data[:orchestration_stacks].lazy_find(stack_ems_ref)) meaning
  #   Resource depends on Stack through :stack attribute
  #
  #              +-----------------------+                                  +-----------------------+
  #              |                       |                                  |                       |
  #              |                       |                                  |                       |
  #              |                       |                                  |                       |
  #              |         Stack         |                                  |         Stack         |
  #              |                       <-----+                            | blacklist: [:parent]  |
  #              |                       |     |                            |                       <---------+
  #              |              :parent  |     |                            |                       |         |
  #              +---^--------------+----+     |    to DAG ->               +---^----------------^--+         |
  #                  |              |          |                                |                |            |
  #                  |              |          |                                |                |            |
  #  +---------------+-------+      +----------+                +---------------+-------+     +--+------------+-------+
  #  |            :stack     |                                  |            :stack     |     | :parent    :internal  |
  #  |                       |                                  |                       |     |                       |
  #  |                       |                                  |                       |     |                       |
  #  |         Resource      |                                  |         Resource      |     |         Stack         |
  #  |                       |                                  |                       |     | whitelist: [:parent]  |
  #  |                       |                                  |                       |     |                       |
  #  |                       |                                  |                       |     |                       |
  #  +-----------------------+                                  +-----------------------+     +-----------------------+
  #
  # 2. Example, cycle is stack -> resource -> stack
  #
  # edge Stack -> Resource is created by
  #   (:parent => @data[:orchestration_stacks_resources].lazy_find(resource_ems_ref, :key => :stack)) meaning Stack
  #   depends on Resource through :parent attribute. Due to the usage of :key => :stack, Stack actually depends on
  #   Resource that has :stack attribute saved.
  #
  # edge Resource -> Stack is created by (:stack => @data[:orchestration_stacks].lazy_find(stack_ems_ref)) meaning
  #   Resource depends on Stack through :stack attribute
  #
  #  +-----------------------+                                  +-----------------------+
  #  |                       |                                  |                       |
  #  |                       |                                  |                       |
  #  |                       |                                  |                       |
  #  |         Stack         |                                  |         Stack         |
  #  |                       |                                  | blacklist: [:parent]  |
  #  |                       |                                  |                       |
  #  |              :parent  |                                  |                       <--+
  #  +---^-------------+-----+                                  +---------------^-------+  |
  #      |             |               to DAG ->                                |          |
  #      |             |                                                        |          |
  #      |             |                                        +---------------+-------+  |
  #  +---+-------------v-----+                                  |            :stack     |  |
  #  |   :stack              |                                  |                       |  |
  #  |                       |                                  |                       |  |
  #  |                       |                                  |         Resource      |  |
  #  |        Resource       |                                  |                       |  |
  #  |                       |                                  |                       |  |
  #  |                       |                                  |                       |  |
  #  |                       |                                  +----^------------------+  |
  #  +-----------------------+                                       |                     |
  #                                                                  |                     |
  #                                                             +----+------------------+  |
  #                                                             | :parent      :internal+--+
  #                                                             |                       |
  #                                                             |                       |
  #                                                             |         Stack         |
  #                                                             | whitelist: [:parent]  |
  #                                                             |                       |
  #                                                             |                       |
  #                                                             +-----------------------+
  #
  # 3. Example, cycle is network_port -> stack -> resource -> stack
  #
  # edge Stack -> Resource is created by
  #   (:parent => @data[:orchestration_stacks_resources].lazy_find(resource_ems_ref, :key => :stack)) meaning Stack
  #   depends on Resource through :parent attribute. Due to the usage of :key => :stack, Stack actually depends on
  #   Resource that has :stack attribute saved.
  #
  # edge Resource -> Stack is created by (:stack => @data[:orchestration_stacks].lazy_find(stack_ems_ref)) meaning
  #   Resource depends on Stack through :stack attribute
  #
  # edge NetworkPort -> Stack is created by
  #   (:device => @data[:orchestration_stacks].lazy_find(stack_ems_ref, :key => :parent)) meaning that NetworkPort
  #   depends on Stack through :device polymorphic attribute. Due to the usage of :key => :parent, NetworkPort actually
  #   depends on Stack with :parent attribute saved.
  #
  #   So in this case the DAG conversion also needs to change the edge which was NetworkPort -> Stack(with blacklist)
  #   to NetworkPort -> Stack(with whitelist)
  #
  #  +-----------------------+     +-----------------------+
  #  |                       |     |                       |
  #  |                       |     |                       |
  #  |                       |     |                       |
  #  |       NetworkPort     |     |         Stack         |
  #  |                       |  +-->                       |
  #  |                       |  |  |                       |
  #  |         :device       |  |  |              :parent  |
  #  +--------------+--------+  |  +---^-------------+-----+
  #                 |           |      |             |
  #                 +-----------+      |             |
  #                                    |             |
  #                                +---+-------------v-----+
  #                                |   :stack              |
  #                                |                       |
  #                                |                       |
  #                                |        Resource       |
  #                                |                       |
  #                                |                       |
  #                                |                       |
  #                                +-----------------------+
  #
  #                          to DAG
  #                             |
  #                             |
  #                             v
  #
  #  +-----------------------+     +-----------------------+
  #  |                       |     |                       |
  #  |                       |     |                       |
  #  |                       |     |                       |
  #  |       NetworkPort     |     |         Stack         |
  #  |                       |     | blacklist: [:parent]  |
  #  |                       |     |                       |
  #  |        :device        |     |                       <--+
  #  +-----------+-----------+     +---------------^-------+  |
  #              |                                 |          |
  #              |                                 |          |
  #              +--------------+  +---------------+-------+  |
  #                             |  |            :stack     |  |
  #                             |  |                       |  |
  #                             |  |                       |  |
  #                             |  |         Resource      |  |
  #                             |  |                       |  |
  #                             |  |                       |  |
  #                             |  |                       |  |
  #                             |  +----^------------------+  |
  #                             |       |                     |
  #                             |       |                     |
  #                             |  +----+------------------+  |
  #                             |  | :parent      :internal+--+
  #                             |  |                       |
  #                             |  |                       |
  #                             +-->         Stack         |
  #                                | whitelist: [:parent]  |
  #                                |                       |
  #                                |                       |
  #                                +-----------------------+
  #
  # 4. Example, cycle is network_port -> network_port -> stack -> resource -> stack
  #
  # edge Stack -> Resource is created by
  #   (:parent => @data[:orchestration_stacks_resources].lazy_find(resource_ems_ref, :key => :stack)) meaning Stack
  #   depends on Resource through :parent attribute. Due to the usage of :key => :stack, Stack actually depends on
  #   Resource that has :stack attribute saved.
  #
  # edge Resource -> Stack is created by (:stack => @data[:orchestration_stacks].lazy_find(stack_ems_ref)) meaning
  #   Resource depends on Stack through :stack attribute
  #
  # edge NetworkPort -> NetworkPort is created by (:device => @data[:network_ports].lazy_find(network_port_ems_ref))
  #   meaning that NetworkPort depends on NetworkPort through :device polymorphic attribute
  #
  # edge NetworkPort -> Stack is created by
  #   (:device => @data[:orchestration_stacks].lazy_find(stack_ems_ref, :key => :parent)) meaning that NetworkPort
  #   depends on Stack through :device polymorphic attribute. Due to the usage of :key => :parent, NetworkPort actually
  #   depends on Stack with :parent attribute saved.
  #
  #   So in this case the DAG conversion also needs to change the edge which was NetworkPort(with whitelist) ->
  #   Stack(with blacklist) to NetworkPort(with whitelist) -> Stack(with whitelist)
  #
  #  +-----------------------+     +-----------------------+
  #  |                       |     |                       |
  #  |                       |     |                       |
  #  |                       |     |                       |
  #  |       NetworkPort     |     |         Stack         |
  #  |                       |  +-->                       |
  #  |                       |  |  |                       |
  #  |         :device       |  |  |              :parent  |
  #  +---------+-^--+--------+  |  +---^-------------+-----+
  #            | |  |           |      |             |
  #            +-+  +-----------+      |             |
  #                                    |             |
  #                                +---+-------------v-----+
  #                                |   :stack              |
  #                                |                       |
  #                                |                       |
  #                                |        Resource       |
  #                                |                       |
  #                                |                       |
  #                                |                       |
  #                                +-----------------------+
  #
  #                          to DAG
  #                             |
  #                             |
  #                             v
  #
  #  +-----------------------+     +-----------------------+
  #  |                       |     |                       |
  #  |                       |     |                       |
  #  |                       |     |                       |
  #  |       NetworkPort     |     |         Stack         |
  #  |  blacklist: [:device] |     | blacklist: [:parent]  |
  #  |                       |     |                       |
  #  |                       |     |                       <--+
  #  +----^------^-----------+     +---------------^-------+  |
  #       |      |                                 |          |
  #       |      |                                 |          |
  #       |      | +------------+  +---------------+-------+  |
  #       |      | |            |  |            :stack     |  |
  #       |      | |            |  |                       |  |
  #  +----+------+-+---------+  |  |                       |  |
  #  |:internal :device      |  |  |         Resource      |  |
  #  |                       |  |  |                       |  |
  #  |                       |  |  |                       |  |
  #  |       NetworkPort     |  |  |                       |  |
  #  |  whitelist: [:device] |  |  +----^------------------+  |
  #  |                       |  |       |                     |
  #  |                       |  |       |                     |
  #  +-----------------------+  |  +----+------------------+  |
  #                             |  | :parent      :internal+--+
  #                             |  |                       |
  #                             |  |                       |
  #                             +-->         Stack         |
  #                                | whitelist: [:parent]  |
  #                                |                       |
  #                                |                       |
  #                                +-----------------------+
  #
  # 5. Example, cycle is network_port -> network_port using key
  #
  # The edge NetworkPort -> NetworkPort is created by
  #   :device => @data[:network_ports].lazy_find(network_port_ems_ref)
  #   and
  #   :device => @data[:network_ports].lazy_find(network_port_ems_ref, :key => :device)
  #   which creates an unsolvable cycle, since NetworkPort depends on NetworkPort with :device attribute saved, through
  #   :device attribute
  #
  #  +-----------------------+                 +-----------------------+
  #  |                       |                 |                       |
  #  |                       |                 |                       |
  #  |                       |                 |                       |
  #  |       NetworkPort     |                 |       NetworkPort     |
  #  |  blacklist: [:device] |                 |  blacklist: [:device] |
  #  |                       |                 |                       |
  #  |       :device         |                 |                       |
  #  +---------+--^----------+    to DAG ->    +------------------^----+
  #            |  |                                               |
  #            |  |                                               |
  #            +--+                                   +--+        |
  #                                                   |  |        |
  #                                                   |  |        |
  #                                            +------+--v--------+----+
  #                                            |    :device   :internal|
  #                                            |                       |
  #                                            |                       |
  #                                            |       NetworkPort     |
  #                                            |  whitelist: [:device] |
  #                                            |                       |
  #                                            |                       |
  #                                            +-----------------------+
  # We can see that the cycle just moved to NetworkPort(with whitelist), since the only way to solve this dependency
  # is to actually store records of the NetworkPort in a certain order with a custom saving method.
  #
  ######################################################################################################################
  #
  # Test all settings for ManagerRefresh::SaveInventory
  [{:inventory_object_saving_strategy => nil},
   {:inventory_object_saving_strategy => :recursive},
  ].each do |inventory_object_settings|
    context "with settings #{inventory_object_settings}" do
      before :each do
        @zone        = FactoryGirl.create(:zone)
        @ems         = FactoryGirl.create(:ems_cloud, :zone => @zone)
        @ems_network = FactoryGirl.create(:ems_network, :zone => @zone, :parent_manager => @ems)

        allow(@ems.class).to receive(:ems_type).and_return(:mock)
        allow(Settings.ems_refresh).to receive(:mock).and_return(inventory_object_settings)
      end

      context 'with empty DB' do
        before :each do
          initialize_inventory_collections
        end

        it 'creates and updates a graph of InventoryCollections with cycle stack -> stack' do
          # Doing 2 times, to make sure we first create all records then update all records
          2.times do
            # Fill the InventoryCollections with data
            init_stack_data_with_stack_stack_cycle
            init_resource_data

            add_data_to_inventory_collection(@data[:orchestration_stacks],
                                             @orchestration_stack_data_0_1,
                                             @orchestration_stack_data_0_2,
                                             @orchestration_stack_data_1_11,
                                             @orchestration_stack_data_1_12,
                                             @orchestration_stack_data_11_21,
                                             @orchestration_stack_data_12_22,
                                             @orchestration_stack_data_12_23)
            add_data_to_inventory_collection(@data[:orchestration_stacks_resources],
                                             @orchestration_stack_resource_data_1_11,
                                             @orchestration_stack_resource_data_1_11_1,
                                             @orchestration_stack_resource_data_1_12,
                                             @orchestration_stack_resource_data_1_12_1,
                                             @orchestration_stack_resource_data_11_21,
                                             @orchestration_stack_resource_data_12_22,
                                             @orchestration_stack_resource_data_12_23)

            # Invoke the InventoryCollections saving
            ManagerRefresh::SaveInventory.save_inventory(@ems, @data)

            # Assert saved data
            assert_full_inventory_collections_graph
          end
        end

        it 'creates and updates a graph of InventoryCollections with cycle stack -> resource -> stack, through resource :key' do
          # Doing 2 times, to make sure we first create all records then update all records
          2.times do
            # Fill the InventoryCollections with data
            init_stack_data_with_stack_resource_stack_cycle
            init_resource_data

            add_data_to_inventory_collection(@data[:orchestration_stacks],
                                             @orchestration_stack_data_0_1,
                                             @orchestration_stack_data_0_2,
                                             @orchestration_stack_data_1_11,
                                             @orchestration_stack_data_1_12,
                                             @orchestration_stack_data_11_21,
                                             @orchestration_stack_data_12_22,
                                             @orchestration_stack_data_12_23)
            add_data_to_inventory_collection(@data[:orchestration_stacks_resources],
                                             @orchestration_stack_resource_data_1_11,
                                             @orchestration_stack_resource_data_1_11_1,
                                             @orchestration_stack_resource_data_1_12,
                                             @orchestration_stack_resource_data_1_12_1,
                                             @orchestration_stack_resource_data_11_21,
                                             @orchestration_stack_resource_data_12_22,
                                             @orchestration_stack_resource_data_12_23)

            # Invoke the InventoryCollections saving
            ManagerRefresh::SaveInventory.save_inventory(@ems, @data)

            # Assert saved data
            assert_full_inventory_collections_graph
          end
        end
      end

      context 'with empty DB and reversed InventoryCollections' do
        before :each do
          initialize_inventory_collections_reversed
        end

        it 'creates and updates a graph of InventoryCollections with cycle stack -> stack' do
          # Doing 2 times, to make sure we first create all records then update all records
          2.times do
            # Fill the InventoryCollections with data
            init_stack_data_with_stack_stack_cycle
            init_resource_data

            add_data_to_inventory_collection(@data[:orchestration_stacks],
                                             @orchestration_stack_data_0_1,
                                             @orchestration_stack_data_0_2,
                                             @orchestration_stack_data_1_11,
                                             @orchestration_stack_data_1_12,
                                             @orchestration_stack_data_11_21,
                                             @orchestration_stack_data_12_22,
                                             @orchestration_stack_data_12_23)
            add_data_to_inventory_collection(@data[:orchestration_stacks_resources],
                                             @orchestration_stack_resource_data_1_11,
                                             @orchestration_stack_resource_data_1_11_1,
                                             @orchestration_stack_resource_data_1_12,
                                             @orchestration_stack_resource_data_1_12_1,
                                             @orchestration_stack_resource_data_11_21,
                                             @orchestration_stack_resource_data_12_22,
                                             @orchestration_stack_resource_data_12_23)

            # Invoke the InventoryCollections saving
            ManagerRefresh::SaveInventory.save_inventory(@ems, @data)

            # Assert saved data
            assert_full_inventory_collections_graph
          end
        end

        it 'creates and updates a graph of InventoryCollections with cycle stack -> resource -> stack, through resource :key' do
          # Doing 2 times, to make sure we first create all records then update all records
          2.times do
            # Fill the InventoryCollections with data
            init_stack_data_with_stack_resource_stack_cycle
            init_resource_data

            add_data_to_inventory_collection(@data[:orchestration_stacks],
                                             @orchestration_stack_data_0_1,
                                             @orchestration_stack_data_0_2,
                                             @orchestration_stack_data_1_11,
                                             @orchestration_stack_data_1_12,
                                             @orchestration_stack_data_11_21,
                                             @orchestration_stack_data_12_22,
                                             @orchestration_stack_data_12_23)
            add_data_to_inventory_collection(@data[:orchestration_stacks_resources],
                                             @orchestration_stack_resource_data_1_11,
                                             @orchestration_stack_resource_data_1_11_1,
                                             @orchestration_stack_resource_data_1_12,
                                             @orchestration_stack_resource_data_1_12_1,
                                             @orchestration_stack_resource_data_11_21,
                                             @orchestration_stack_resource_data_12_22,
                                             @orchestration_stack_resource_data_12_23)

            # Invoke the InventoryCollections saving
            ManagerRefresh::SaveInventory.save_inventory(@ems, @data)

            # Assert saved data
            assert_full_inventory_collections_graph
          end
        end
      end

      context 'with complex cycle' do
        it 'test network_port -> stack -> resource -> stack' do
          @data                                  = {}
          @data[:orchestration_stacks]           = ::ManagerRefresh::InventoryCollection.new(
            ManageIQ::Providers::CloudManager::OrchestrationStack,
            :parent      => @ems,
            :association => :orchestration_stacks)
          @data[:orchestration_stacks_resources] = ::ManagerRefresh::InventoryCollection.new(
            OrchestrationStackResource,
            :parent      => @ems,
            :association => :orchestration_stacks_resources)
          @data[:network_ports]                  = ::ManagerRefresh::InventoryCollection.new(
            NetworkPort,
            :parent      => @ems.network_manager,
            :association => :network_ports)

          init_stack_data_with_stack_resource_stack_cycle
          init_resource_data

          @network_port_1 = network_port_data(1).merge(
            :device => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("1_11")[:ems_ref],
                                                              :key => :parent)
          )
          @network_port_2 = network_port_data(2).merge(
            :device => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("11_21")[:ems_ref],
                                                              :key => :parent)
          )
          @network_port_3 = network_port_data(3).merge(
            :device => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("12_22")[:ems_ref],
                                                              :key => :parent)
          )

          add_data_to_inventory_collection(@data[:orchestration_stacks],
                                           @orchestration_stack_data_0_1,
                                           @orchestration_stack_data_0_2,
                                           @orchestration_stack_data_1_11,
                                           @orchestration_stack_data_1_12,
                                           @orchestration_stack_data_11_21,
                                           @orchestration_stack_data_12_22,
                                           @orchestration_stack_data_12_23)
          add_data_to_inventory_collection(@data[:orchestration_stacks_resources],
                                           @orchestration_stack_resource_data_1_11,
                                           @orchestration_stack_resource_data_1_11_1,
                                           @orchestration_stack_resource_data_1_12,
                                           @orchestration_stack_resource_data_1_12_1,
                                           @orchestration_stack_resource_data_11_21,
                                           @orchestration_stack_resource_data_12_22,
                                           @orchestration_stack_resource_data_12_23)
          add_data_to_inventory_collection(@data[:network_ports],
                                           @network_port_1,
                                           @network_port_2,
                                           @network_port_3)

          # Invoke the InventoryCollections saving
          ManagerRefresh::SaveInventory.save_inventory(@ems, @data)

          # Assert saved data
          assert_full_inventory_collections_graph

          network_port_1 = NetworkPort.find_by(:ems_ref => "network_port_ems_ref_1")
          network_port_2 = NetworkPort.find_by(:ems_ref => "network_port_ems_ref_2")
          network_port_3 = NetworkPort.find_by(:ems_ref => "network_port_ems_ref_3")

          orchestration_stack_0_1  = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_0_1")
          orchestration_stack_1_11 = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_1_11")
          orchestration_stack_1_12 = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_1_12")
          expect(network_port_1.device).to eq(orchestration_stack_0_1)
          expect(network_port_2.device).to eq(orchestration_stack_1_11)
          expect(network_port_3.device).to eq(orchestration_stack_1_12)
        end

        it 'test network_port -> stack -> resource -> stack reverted' do
          @data                                  = {}
          @data[:network_ports]                  = ::ManagerRefresh::InventoryCollection.new(
            NetworkPort,
            :parent      => @ems.network_manager,
            :association => :network_ports)
          @data[:orchestration_stacks_resources] = ::ManagerRefresh::InventoryCollection.new(
            OrchestrationStackResource,
            :parent      => @ems,
            :association => :orchestration_stacks_resources)
          @data[:orchestration_stacks]           = ::ManagerRefresh::InventoryCollection.new(
            ManageIQ::Providers::CloudManager::OrchestrationStack,
            :parent      => @ems,
            :association => :orchestration_stacks)

          init_stack_data_with_stack_resource_stack_cycle
          init_resource_data

          @network_port_1 = network_port_data(1).merge(
            :device => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("1_11")[:ems_ref],
                                                              :key => :parent)
          )
          @network_port_2 = network_port_data(2).merge(
            :device => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("11_21")[:ems_ref],
                                                              :key => :parent)
          )
          @network_port_3 = network_port_data(3).merge(
            :device => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("12_22")[:ems_ref],
                                                              :key => :parent)
          )

          add_data_to_inventory_collection(@data[:orchestration_stacks],
                                           @orchestration_stack_data_0_1,
                                           @orchestration_stack_data_0_2,
                                           @orchestration_stack_data_1_11,
                                           @orchestration_stack_data_1_12,
                                           @orchestration_stack_data_11_21,
                                           @orchestration_stack_data_12_22,
                                           @orchestration_stack_data_12_23)
          add_data_to_inventory_collection(@data[:orchestration_stacks_resources],
                                           @orchestration_stack_resource_data_1_11,
                                           @orchestration_stack_resource_data_1_11_1,
                                           @orchestration_stack_resource_data_1_12,
                                           @orchestration_stack_resource_data_1_12_1,
                                           @orchestration_stack_resource_data_11_21,
                                           @orchestration_stack_resource_data_12_22,
                                           @orchestration_stack_resource_data_12_23)
          add_data_to_inventory_collection(@data[:network_ports],
                                           @network_port_1,
                                           @network_port_2,
                                           @network_port_3)

          # Invoke the InventoryCollections saving
          ManagerRefresh::SaveInventory.save_inventory(@ems, @data)
          # Assert saved data
          assert_full_inventory_collections_graph

          network_port_1 = NetworkPort.find_by(:ems_ref => "network_port_ems_ref_1")
          network_port_2 = NetworkPort.find_by(:ems_ref => "network_port_ems_ref_2")
          network_port_3 = NetworkPort.find_by(:ems_ref => "network_port_ems_ref_3")

          orchestration_stack_0_1  = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_0_1")
          orchestration_stack_1_11 = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_1_11")
          orchestration_stack_1_12 = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_1_12")
          expect(network_port_1.device).to eq(orchestration_stack_0_1)
          expect(network_port_2.device).to eq(orchestration_stack_1_11)
          expect(network_port_3.device).to eq(orchestration_stack_1_12)
        end

        it "test network_port -> network_port through network_port's :device can't be converted to DAG" do
          # We are creating an unsolvable cycle, cause only option to save this data is writing a custom method, that
          # saved the data in a correct order. In this case, we would need to save this data by creating a tree of
          # data dependencies and saving it according to the tree.
          @data                 = {}
          @data[:network_ports] = ::ManagerRefresh::InventoryCollection.new(
            NetworkPort,
            :parent      => @ems.network_manager,
            :association => :network_ports)

          @network_port_1 = network_port_data(1).merge(
            :device => @data[:network_ports].lazy_find(network_port_data(1)[:ems_ref])
          )
          @network_port_2 = network_port_data(2).merge(
            :device => @data[:network_ports].lazy_find(network_port_data(1)[:ems_ref],
                                                       :key => :device)
          )

          add_data_to_inventory_collection(@data[:network_ports],
                                           @network_port_1,
                                           @network_port_2)

          # Invoke the InventoryCollections saving and check we raise an exception that a cycle was found, after we
          # attempted to remove the cycles.
          expect { ManagerRefresh::SaveInventory.save_inventory(@ems, @data) }.to raise_error(/^Cycle from /)
        end

        it 'test network_port -> network_port -> stack -> resource -> stack' do
          # TODO(lmola) this test should pass, since there is not an unbreakable cycle, we should move only edge
          # network_port ->> stack to network_port -> stack_new. Now we move also edge created by untangling to cycle,
          # that was network_port -> network_port, then it's correctly network_port_new -> network_port, but then
          # the transitive edge check catch this and it's turned to network_port_new -> network_port_new, which is a
          # cycle again.
          # What this needs to be:
          #
          # It can happen, that one edge is transitive but other is not using the same relations:
          # So this is a transitive edge:
          #  :device => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("11_21")[:ems_ref],
          #                                                   :key => :parent)
          # And this is not:
          #  :device => @data[:network_ports].lazy_find(network_port_data(4)[:ems_ref])
          #
          # By correctly storing that :device is causing transitive edge only when pointing to
          # @data[:orchestration_stacks] but not when pointing to @data[:network_ports], then we can transform the
          # edge correctly and this cycle is solvable.
          @data                                  = {}
          @data[:orchestration_stacks]           = ::ManagerRefresh::InventoryCollection.new(
            ManageIQ::Providers::CloudManager::OrchestrationStack,
            :parent      => @ems,
            :association => :orchestration_stacks)
          @data[:orchestration_stacks_resources] = ::ManagerRefresh::InventoryCollection.new(
            OrchestrationStackResource,
            :parent      => @ems,
            :association => :orchestration_stacks_resources)
          @data[:network_ports]                  = ::ManagerRefresh::InventoryCollection.new(
            NetworkPort,
            :parent      => @ems.network_manager,
            :association => :network_ports)

          init_stack_data_with_stack_resource_stack_cycle
          init_resource_data

          @network_port_1 = network_port_data(1).merge(
            :device => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("1_11")[:ems_ref],
                                                              :key => :parent)
          )
          @network_port_2 = network_port_data(2).merge(
            :device => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("11_21")[:ems_ref],
                                                              :key => :parent)
          )
          @network_port_3 = network_port_data(3).merge(
            :device => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("12_22")[:ems_ref],
                                                              :key => :parent)
          )
          @network_port_4 = network_port_data(4).merge(
            :device => @data[:network_ports].lazy_find(network_port_data(3)[:ems_ref])
          )
          @network_port_5 = network_port_data(5).merge(
            :device => @data[:network_ports].lazy_find(network_port_data(4)[:ems_ref])
          )
          @network_port_6 = network_port_data(7).merge(
            :device => @data[:network_ports].lazy_find(network_port_data(7)[:ems_ref])
          )

          add_data_to_inventory_collection(@data[:orchestration_stacks],
                                           @orchestration_stack_data_0_1,
                                           @orchestration_stack_data_0_2,
                                           @orchestration_stack_data_1_11,
                                           @orchestration_stack_data_1_12,
                                           @orchestration_stack_data_11_21,
                                           @orchestration_stack_data_12_22,
                                           @orchestration_stack_data_12_23)
          add_data_to_inventory_collection(@data[:orchestration_stacks_resources],
                                           @orchestration_stack_resource_data_1_11,
                                           @orchestration_stack_resource_data_1_11_1,
                                           @orchestration_stack_resource_data_1_12,
                                           @orchestration_stack_resource_data_1_12_1,
                                           @orchestration_stack_resource_data_11_21,
                                           @orchestration_stack_resource_data_12_22,
                                           @orchestration_stack_resource_data_12_23)
          add_data_to_inventory_collection(@data[:network_ports],
                                           @network_port_1,
                                           @network_port_2,
                                           @network_port_3,
                                           @network_port_4,
                                           @network_port_5,
                                           @network_port_6)

          # Invoke the InventoryCollections saving and check we raise an exception that a cycle was found, after we
          # attempted to remove the cycles.
          # TODO(lsmola) make this spec pass, by enhancing the logic around transitive edges
          expect { ManagerRefresh::SaveInventory.save_inventory(@ems, @data) }.to raise_error(/^Cycle from /)
        end

        it 'test network_port -> stack -> resource -> stack and network_port -> resource -> stack -> resource -> stack ' do
          @data                                  = {}
          @data[:orchestration_stacks]           = ::ManagerRefresh::InventoryCollection.new(
            ManageIQ::Providers::CloudManager::OrchestrationStack,
            :parent      => @ems,
            :association => :orchestration_stacks)
          @data[:orchestration_stacks_resources] = ::ManagerRefresh::InventoryCollection.new(
            OrchestrationStackResource,
            :parent      => @ems,
            :association => :orchestration_stacks_resources)
          @data[:network_ports]                  = ::ManagerRefresh::InventoryCollection.new(
            NetworkPort,
            :parent      => @ems.network_manager,
            :association => :network_ports)

          init_stack_data_with_stack_resource_stack_cycle
          init_resource_data

          @network_port_1 = network_port_data(1).merge(
            :device => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("1_11")[:ems_ref],
                                                              :key => :parent)
          )
          @network_port_2 = network_port_data(2).merge(
            :device => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("11_21")[:ems_ref],
                                                              :key => :parent)
          )
          @network_port_3 = network_port_data(3).merge(
            :device => @data[:orchestration_stacks_resources].lazy_find(orchestration_stack_data("12_22")[:ems_ref],
                                                                        :key => :stack)
          )
          @network_port_4 = network_port_data(4).merge(
            :device => @data[:orchestration_stacks_resources].lazy_find(orchestration_stack_data("12_22")[:ems_ref])
          )

          add_data_to_inventory_collection(@data[:orchestration_stacks],
                                           @orchestration_stack_data_0_1,
                                           @orchestration_stack_data_0_2,
                                           @orchestration_stack_data_1_11,
                                           @orchestration_stack_data_1_12,
                                           @orchestration_stack_data_11_21,
                                           @orchestration_stack_data_12_22,
                                           @orchestration_stack_data_12_23)
          add_data_to_inventory_collection(@data[:orchestration_stacks_resources],
                                           @orchestration_stack_resource_data_1_11,
                                           @orchestration_stack_resource_data_1_11_1,
                                           @orchestration_stack_resource_data_1_12,
                                           @orchestration_stack_resource_data_1_12_1,
                                           @orchestration_stack_resource_data_11_21,
                                           @orchestration_stack_resource_data_12_22,
                                           @orchestration_stack_resource_data_12_23)
          add_data_to_inventory_collection(@data[:network_ports],
                                           @network_port_1,
                                           @network_port_2,
                                           @network_port_3,
                                           @network_port_4)

          # Invoke the InventoryCollections saving
          ManagerRefresh::SaveInventory.save_inventory(@ems, @data)

          # Assert saved data
          assert_full_inventory_collections_graph

          network_port_1 = NetworkPort.find_by(:ems_ref => "network_port_ems_ref_1")
          network_port_2 = NetworkPort.find_by(:ems_ref => "network_port_ems_ref_2")
          network_port_3 = NetworkPort.find_by(:ems_ref => "network_port_ems_ref_3")
          network_port_4 = NetworkPort.find_by(:ems_ref => "network_port_ems_ref_4")

          orchestration_stack_0_1  = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_0_1")
          orchestration_stack_1_11 = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_1_11")
          orchestration_stack_1_12 = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_1_12")

          orchestration_resource_12_22 = OrchestrationStackResource.find_by(:ems_ref => "stack_ems_ref_12_22")

          expect(network_port_1.device).to eq(orchestration_stack_0_1)
          expect(network_port_2.device).to eq(orchestration_stack_1_11)
          expect(network_port_3.device).to eq(orchestration_stack_1_12)
          expect(network_port_4.device).to eq(orchestration_resource_12_22)
        end
      end

      context 'with the existing data in the DB' do
        it 'updates existing records with a graph of InventoryCollections with cycle stack -> stack' do
          # Create all relations directly in DB
          initialize_mocked_records
          # And check the relations are correct
          assert_full_inventory_collections_graph

          # Now we will update existing DB using SaveInventory
          # Fill the InventoryCollections with data
          initialize_inventory_collections
          init_stack_data_with_stack_stack_cycle
          init_resource_data

          add_data_to_inventory_collection(@data[:orchestration_stacks],
                                           @orchestration_stack_data_0_1,
                                           @orchestration_stack_data_0_2,
                                           @orchestration_stack_data_1_11,
                                           @orchestration_stack_data_1_12,
                                           @orchestration_stack_data_11_21,
                                           @orchestration_stack_data_12_22,
                                           @orchestration_stack_data_12_23)
          add_data_to_inventory_collection(@data[:orchestration_stacks_resources],
                                           @orchestration_stack_resource_data_1_11,
                                           @orchestration_stack_resource_data_1_11_1,
                                           @orchestration_stack_resource_data_1_12,
                                           @orchestration_stack_resource_data_1_12_1,
                                           @orchestration_stack_resource_data_11_21,
                                           @orchestration_stack_resource_data_12_22,
                                           @orchestration_stack_resource_data_12_23)

          # Invoke the InventoryCollections saving
          ManagerRefresh::SaveInventory.save_inventory(@ems, @data)

          # Assert saved data
          assert_full_inventory_collections_graph

          # Check that we only updated the existing records
          orchestration_stack_0_1   = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_0_1")
          orchestration_stack_0_2   = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_0_2")
          orchestration_stack_1_11  = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_1_11")
          orchestration_stack_1_12  = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_1_12")
          orchestration_stack_11_21 = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_11_21")
          orchestration_stack_12_22 = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_12_22")
          orchestration_stack_12_23 = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_12_23")

          orchestration_stack_resource_1_11   = OrchestrationStackResource.find_by(
            :ems_ref => "stack_ems_ref_1_11")
          orchestration_stack_resource_1_11_1 = OrchestrationStackResource.find_by(
            :ems_ref => "stack_resource_physical_resource_1_11_1")
          orchestration_stack_resource_1_12   = OrchestrationStackResource.find_by(
            :ems_ref => "stack_ems_ref_1_12")
          orchestration_stack_resource_1_12_1 = OrchestrationStackResource.find_by(
            :ems_ref => "stack_resource_physical_resource_1_12_1")
          orchestration_stack_resource_11_21  = OrchestrationStackResource.find_by(
            :ems_ref => "stack_ems_ref_11_21")
          orchestration_stack_resource_12_22  = OrchestrationStackResource.find_by(
            :ems_ref => "stack_ems_ref_12_22")
          orchestration_stack_resource_12_23  = OrchestrationStackResource.find_by(
            :ems_ref => "stack_ems_ref_12_23")

          expect(orchestration_stack_0_1).to eq(@orchestration_stack_0_1)
          expect(orchestration_stack_0_2).to eq(@orchestration_stack_0_2)
          expect(orchestration_stack_1_11).to eq(@orchestration_stack_1_11)
          expect(orchestration_stack_1_12).to eq(@orchestration_stack_1_12)
          expect(orchestration_stack_11_21).to eq(@orchestration_stack_11_21)
          expect(orchestration_stack_12_22).to eq(@orchestration_stack_12_22)
          expect(orchestration_stack_12_23).to eq(@orchestration_stack_12_23)

          expect(orchestration_stack_resource_1_11).to eq(@orchestration_stack_resource_1_11)
          expect(orchestration_stack_resource_1_11_1).to eq(@orchestration_stack_resource_1_11_1)
          expect(orchestration_stack_resource_1_12).to eq(@orchestration_stack_resource_1_12)
          expect(orchestration_stack_resource_1_12_1).to eq(@orchestration_stack_resource_1_12_1)
          expect(orchestration_stack_resource_11_21).to eq(@orchestration_stack_resource_11_21)
          expect(orchestration_stack_resource_12_22).to eq(@orchestration_stack_resource_12_22)
          expect(orchestration_stack_resource_12_23).to eq(@orchestration_stack_resource_12_23)
        end

        it 'updates existing records with a graph of InventoryCollections with cycle stack -> resource -> stack, through resource :key' do
          # Create all relations directly in DB
          initialize_mocked_records
          # And check the relations are correct
          assert_full_inventory_collections_graph

          # Now we will update existing DB using SaveInventory
          # Fill the InventoryCollections with data
          initialize_inventory_collections
          init_stack_data_with_stack_resource_stack_cycle
          init_resource_data

          add_data_to_inventory_collection(@data[:orchestration_stacks],
                                           @orchestration_stack_data_0_1,
                                           @orchestration_stack_data_0_2,
                                           @orchestration_stack_data_1_11,
                                           @orchestration_stack_data_1_12,
                                           @orchestration_stack_data_11_21,
                                           @orchestration_stack_data_12_22,
                                           @orchestration_stack_data_12_23)
          add_data_to_inventory_collection(@data[:orchestration_stacks_resources],
                                           @orchestration_stack_resource_data_1_11,
                                           @orchestration_stack_resource_data_1_11_1,
                                           @orchestration_stack_resource_data_1_12,
                                           @orchestration_stack_resource_data_1_12_1,
                                           @orchestration_stack_resource_data_11_21,
                                           @orchestration_stack_resource_data_12_22,
                                           @orchestration_stack_resource_data_12_23)

          # Invoke the InventoryCollections saving
          ManagerRefresh::SaveInventory.save_inventory(@ems, @data)

          # Assert saved data
          assert_full_inventory_collections_graph

          # Check that we only updated the existing records
          orchestration_stack_0_1   = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_0_1")
          orchestration_stack_0_2   = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_0_2")
          orchestration_stack_1_11  = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_1_11")
          orchestration_stack_1_12  = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_1_12")
          orchestration_stack_11_21 = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_11_21")
          orchestration_stack_12_22 = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_12_22")
          orchestration_stack_12_23 = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_12_23")

          orchestration_stack_resource_1_11   = OrchestrationStackResource.find_by(
            :ems_ref => "stack_ems_ref_1_11")
          orchestration_stack_resource_1_11_1 = OrchestrationStackResource.find_by(
            :ems_ref => "stack_resource_physical_resource_1_11_1")
          orchestration_stack_resource_1_12   = OrchestrationStackResource.find_by(
            :ems_ref => "stack_ems_ref_1_12")
          orchestration_stack_resource_1_12_1 = OrchestrationStackResource.find_by(
            :ems_ref => "stack_resource_physical_resource_1_12_1")
          orchestration_stack_resource_11_21  = OrchestrationStackResource.find_by(
            :ems_ref => "stack_ems_ref_11_21")
          orchestration_stack_resource_12_22  = OrchestrationStackResource.find_by(
            :ems_ref => "stack_ems_ref_12_22")
          orchestration_stack_resource_12_23  = OrchestrationStackResource.find_by(
            :ems_ref => "stack_ems_ref_12_23")

          expect(orchestration_stack_0_1).to eq(@orchestration_stack_0_1)
          expect(orchestration_stack_0_2).to eq(@orchestration_stack_0_2)
          expect(orchestration_stack_1_11).to eq(@orchestration_stack_1_11)
          expect(orchestration_stack_1_12).to eq(@orchestration_stack_1_12)
          expect(orchestration_stack_11_21).to eq(@orchestration_stack_11_21)
          expect(orchestration_stack_12_22).to eq(@orchestration_stack_12_22)
          expect(orchestration_stack_12_23).to eq(@orchestration_stack_12_23)

          expect(orchestration_stack_resource_1_11).to eq(@orchestration_stack_resource_1_11)
          expect(orchestration_stack_resource_1_11_1).to eq(@orchestration_stack_resource_1_11_1)
          expect(orchestration_stack_resource_1_12).to eq(@orchestration_stack_resource_1_12)
          expect(orchestration_stack_resource_1_12_1).to eq(@orchestration_stack_resource_1_12_1)
          expect(orchestration_stack_resource_11_21).to eq(@orchestration_stack_resource_11_21)
          expect(orchestration_stack_resource_12_22).to eq(@orchestration_stack_resource_12_22)
          expect(orchestration_stack_resource_12_23).to eq(@orchestration_stack_resource_12_23)
        end
      end
    end
  end

  def assert_full_inventory_collections_graph
    orchestration_stack_0_1   = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_0_1")
    orchestration_stack_0_2   = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_0_2")
    orchestration_stack_1_11  = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_1_11")
    orchestration_stack_1_12  = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_1_12")
    orchestration_stack_11_21 = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_11_21")
    orchestration_stack_12_22 = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_12_22")
    orchestration_stack_12_23 = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_12_23")

    orchestration_stack_resource_1_11   = OrchestrationStackResource.find_by(
      :ems_ref => "stack_ems_ref_1_11")
    orchestration_stack_resource_1_11_1 = OrchestrationStackResource.find_by(
      :ems_ref => "stack_resource_physical_resource_1_11_1")
    orchestration_stack_resource_1_12   = OrchestrationStackResource.find_by(
      :ems_ref => "stack_ems_ref_1_12")
    orchestration_stack_resource_1_12_1 = OrchestrationStackResource.find_by(
      :ems_ref => "stack_resource_physical_resource_1_12_1")
    orchestration_stack_resource_11_21  = OrchestrationStackResource.find_by(
      :ems_ref => "stack_ems_ref_11_21")
    orchestration_stack_resource_12_22  = OrchestrationStackResource.find_by(
      :ems_ref => "stack_ems_ref_12_22")
    orchestration_stack_resource_12_23  = OrchestrationStackResource.find_by(
      :ems_ref => "stack_ems_ref_12_23")

    expect(orchestration_stack_0_1.parent).to eq(nil)
    expect(orchestration_stack_0_2.parent).to eq(nil)
    expect(orchestration_stack_1_11.parent).to eq(orchestration_stack_0_1)
    expect(orchestration_stack_1_12.parent).to eq(orchestration_stack_0_1)
    expect(orchestration_stack_11_21.parent).to eq(orchestration_stack_1_11)
    expect(orchestration_stack_12_22.parent).to eq(orchestration_stack_1_12)
    expect(orchestration_stack_12_23.parent).to eq(orchestration_stack_1_12)

    expect(orchestration_stack_0_1.orchestration_stack_resources).to(
      match_array([orchestration_stack_resource_1_11,
                   orchestration_stack_resource_1_11_1,
                   orchestration_stack_resource_1_12,
                   orchestration_stack_resource_1_12_1]))
    expect(orchestration_stack_0_2.orchestration_stack_resources).to(
      match_array(nil))
    expect(orchestration_stack_1_11.orchestration_stack_resources).to(
      match_array([orchestration_stack_resource_11_21]))
    expect(orchestration_stack_1_12.orchestration_stack_resources).to(
      match_array([orchestration_stack_resource_12_22, orchestration_stack_resource_12_23]))
    expect(orchestration_stack_11_21.orchestration_stack_resources).to(
      match_array(nil))
    expect(orchestration_stack_12_22.orchestration_stack_resources).to(
      match_array(nil))
    expect(orchestration_stack_12_23.orchestration_stack_resources).to(
      match_array(nil))

    expect(orchestration_stack_resource_1_11.stack).to eq(orchestration_stack_0_1)
    expect(orchestration_stack_resource_1_11_1.stack).to eq(orchestration_stack_0_1)
    expect(orchestration_stack_resource_1_12.stack).to eq(orchestration_stack_0_1)
    expect(orchestration_stack_resource_1_12_1.stack).to eq(orchestration_stack_0_1)
    expect(orchestration_stack_resource_11_21.stack).to eq(orchestration_stack_1_11)
    expect(orchestration_stack_resource_12_22.stack).to eq(orchestration_stack_1_12)
    expect(orchestration_stack_resource_12_23.stack).to eq(orchestration_stack_1_12)
  end

  def initialize_inventory_collections
    # Initialize the InventoryCollections
    @data                                  = {}
    @data[:orchestration_stacks]           = ::ManagerRefresh::InventoryCollection.new(
      ManageIQ::Providers::CloudManager::OrchestrationStack,
      :parent      => @ems,
      :association => :orchestration_stacks)
    @data[:orchestration_stacks_resources] = ::ManagerRefresh::InventoryCollection.new(
      OrchestrationStackResource,
      :parent      => @ems,
      :association => :orchestration_stacks_resources)
  end

  def initialize_inventory_collections_reversed
    # Initialize the InventoryCollections in reversed order, so we know that untangling of the cycle does not depend on
    # the order of the InventoryCollections
    @data                                  = {}
    @data[:orchestration_stacks_resources] = ::ManagerRefresh::InventoryCollection.new(
      OrchestrationStackResource,
      :parent      => @ems,
      :association => :orchestration_stacks_resources)
    @data[:orchestration_stacks]           = ::ManagerRefresh::InventoryCollection.new(
      ManageIQ::Providers::CloudManager::OrchestrationStack,
      :parent      => @ems,
      :association => :orchestration_stacks)
  end

  def init_stack_data_with_stack_stack_cycle
    @orchestration_stack_data_0_1   = orchestration_stack_data("0_1").merge(
      :parent => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("0_0")[:ems_ref]))
    @orchestration_stack_data_0_2   = orchestration_stack_data("0_2").merge(
      :parent => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("0_0")[:ems_ref]))
    @orchestration_stack_data_1_11  = orchestration_stack_data("1_11").merge(
      :parent => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("0_1")[:ems_ref]))
    @orchestration_stack_data_1_12  = orchestration_stack_data("1_12").merge(
      :parent => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("0_1")[:ems_ref]))
    @orchestration_stack_data_11_21 = orchestration_stack_data("11_21").merge(
      :parent => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("1_11")[:ems_ref]))
    @orchestration_stack_data_12_22 = orchestration_stack_data("12_22").merge(
      :parent => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("1_12")[:ems_ref]))
    @orchestration_stack_data_12_23 = orchestration_stack_data("12_23").merge(
      :parent => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("1_12")[:ems_ref]))
  end

  def init_stack_data_with_stack_resource_stack_cycle
    @orchestration_stack_data_0_1 = orchestration_stack_data("0_1").merge(
      :parent => @data[:orchestration_stacks_resources].lazy_find(orchestration_stack_data("0_1")[:ems_ref],
                                                                  :key => :stack)
    )

    @orchestration_stack_data_0_2 = orchestration_stack_data("0_2").merge(
      :parent => @data[:orchestration_stacks_resources].lazy_find(orchestration_stack_data("0_2")[:ems_ref],
                                                                  :key => :stack)
    )

    @orchestration_stack_data_1_11 = orchestration_stack_data("1_11").merge(
      :parent => @data[:orchestration_stacks_resources].lazy_find(orchestration_stack_data("1_11")[:ems_ref],
                                                                  :key => :stack)
    )

    @orchestration_stack_data_1_12 = orchestration_stack_data("1_12").merge(
      :parent => @data[:orchestration_stacks_resources].lazy_find(orchestration_stack_data("1_12")[:ems_ref],
                                                                  :key => :stack)
    )

    @orchestration_stack_data_11_21 = orchestration_stack_data("11_21").merge(
      :parent => @data[:orchestration_stacks_resources].lazy_find(orchestration_stack_data("11_21")[:ems_ref],
                                                                  :key => :stack)
    )

    @orchestration_stack_data_12_22 = orchestration_stack_data("12_22").merge(
      :parent => @data[:orchestration_stacks_resources].lazy_find(orchestration_stack_data("12_22")[:ems_ref],
                                                                  :key => :stack)
    )

    @orchestration_stack_data_12_23 = orchestration_stack_data("12_23").merge(
      :parent => @data[:orchestration_stacks_resources].lazy_find(orchestration_stack_data("12_23")[:ems_ref],
                                                                  :key => :stack)
    )
  end

  def init_resource_data
    @orchestration_stack_resource_data_1_11   = orchestration_stack_resource_data("1_11").merge(
      :ems_ref => orchestration_stack_data("1_11")[:ems_ref],
      :stack   => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("0_1")[:ems_ref]),
    )
    @orchestration_stack_resource_data_1_11_1 = orchestration_stack_resource_data("1_11_1").merge(
      :stack => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("0_1")[:ems_ref]),
    )
    @orchestration_stack_resource_data_1_12   = orchestration_stack_resource_data("1_12").merge(
      :ems_ref => orchestration_stack_data("1_12")[:ems_ref],
      :stack   => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("0_1")[:ems_ref]),
    )
    @orchestration_stack_resource_data_1_12_1 = orchestration_stack_resource_data("1_12_1").merge(
      :stack => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("0_1")[:ems_ref]),
    )
    @orchestration_stack_resource_data_11_21  = orchestration_stack_resource_data("11_21").merge(
      :ems_ref => orchestration_stack_data("11_21")[:ems_ref],
      :stack   => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("1_11")[:ems_ref]),
    )
    @orchestration_stack_resource_data_12_22  = orchestration_stack_resource_data("12_22").merge(
      :ems_ref => orchestration_stack_data("12_22")[:ems_ref],
      :stack   => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("1_12")[:ems_ref]),
    )
    @orchestration_stack_resource_data_12_23  = orchestration_stack_resource_data("12_23").merge(
      :ems_ref => orchestration_stack_data("12_23")[:ems_ref],
      :stack   => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("1_12")[:ems_ref]),
    )
  end

  def initialize_mocked_records
    @orchestration_stack_0_1   = FactoryGirl.create(
      :orchestration_stack_cloud,
      orchestration_stack_data("0_1").merge(
        :ext_management_system => @ems,
        :parent                => nil))
    @orchestration_stack_0_2   = FactoryGirl.create(
      :orchestration_stack_cloud,
      orchestration_stack_data("0_2").merge(
        :ext_management_system => @ems,
        :parent                => nil))
    @orchestration_stack_1_11  = FactoryGirl.create(
      :orchestration_stack_cloud,
      orchestration_stack_data("1_11").merge(
        :ext_management_system => @ems,
        :parent                => @orchestration_stack_0_1))
    @orchestration_stack_1_12  = FactoryGirl.create(
      :orchestration_stack_cloud,
      orchestration_stack_data("1_12").merge(
        :ext_management_system => @ems,
        :parent                => @orchestration_stack_0_1))
    @orchestration_stack_11_21 = FactoryGirl.create(
      :orchestration_stack_cloud,
      orchestration_stack_data("11_21").merge(
        :ext_management_system => @ems,
        :parent                => @orchestration_stack_1_11))
    @orchestration_stack_12_22 = FactoryGirl.create(
      :orchestration_stack_cloud,
      orchestration_stack_data("12_22").merge(
        :ext_management_system => @ems,
        :parent                => @orchestration_stack_1_12))
    @orchestration_stack_12_23 = FactoryGirl.create(
      :orchestration_stack_cloud,
      orchestration_stack_data("12_23").merge(
        :ext_management_system => @ems,
        :parent                => @orchestration_stack_1_12))

    @orchestration_stack_resource_1_11   = FactoryGirl.create(
      :orchestration_stack_resource,
      orchestration_stack_resource_data("1_11").merge(
        :ems_ref => orchestration_stack_data("1_11")[:ems_ref],
        :stack   => @orchestration_stack_0_1,
      ))
    @orchestration_stack_resource_1_11_1 = FactoryGirl.create(
      :orchestration_stack_resource,
      orchestration_stack_resource_data("1_11_1").merge(
        :stack => @orchestration_stack_0_1,
      ))
    @orchestration_stack_resource_1_12   = FactoryGirl.create(
      :orchestration_stack_resource,
      orchestration_stack_resource_data("1_12").merge(
        :ems_ref => orchestration_stack_data("1_12")[:ems_ref],
        :stack   => @orchestration_stack_0_1,
      ))
    @orchestration_stack_resource_1_12_1 = FactoryGirl.create(
      :orchestration_stack_resource,
      orchestration_stack_resource_data("1_12_1").merge(
        :stack => @orchestration_stack_0_1,
      ))
    @orchestration_stack_resource_11_21  = FactoryGirl.create(
      :orchestration_stack_resource,
      orchestration_stack_resource_data("11_21").merge(
        :ems_ref => orchestration_stack_data("11_21")[:ems_ref],
        :stack   => @orchestration_stack_1_11,
      ))
    @orchestration_stack_resource_12_22  = FactoryGirl.create(
      :orchestration_stack_resource,
      orchestration_stack_resource_data("12_22").merge(
        :ems_ref => orchestration_stack_data("12_22")[:ems_ref],
        :stack   => @orchestration_stack_1_12,
      ))
    @orchestration_stack_resource_12_23  = FactoryGirl.create(
      :orchestration_stack_resource,
      orchestration_stack_resource_data("12_23").merge(
        :ems_ref => orchestration_stack_data("12_23")[:ems_ref],
        :stack   => @orchestration_stack_1_12,
      ))
  end
end
