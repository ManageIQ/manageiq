require_relative 'spec_helper'
require_relative 'spec_parsed_data'

describe ManagerRefresh::SaveInventory do
  include SpecHelper
  include SpecParsedData

  ######################################################################################################################
  #
  # Testing SaveInventory for general graph of the DtoCollection dependencies, testing that relations
  # are saved correctly for a testing set of DtoCollections whose dependencies look like:
  #
  # 1. Example, cycle is stack -> stack
  #
  #                   +---------------+
  #                   |               <-----+
  #                   |     Stack     |     |
  #                   |               +-----+
  #                   +-------^-------+
  #                           |
  #                           |
  #                           |
  #                   +-------+-------+
  #                   |               |
  #                   |    Resource   |
  #                   |               |
  #                   +---------------+
  #
  # 2. Example, cycle is stack -> resource -> stack
  #
  #                   +---------------+
  #                   |               |
  #                   |     Stack     |
  #                   |               |
  #                   +---^------+----+
  #                       |      |
  #                       |      |
  #                       |      |
  #                   +---+------v----+
  #                   |               |
  #                   |    Resource   |
  #                   |               |
  #                   +---------------+
  ######################################################################################################################
  #
  # Test all settings for ManagerRefresh::SaveInventory
  [{:dto_saving_strategy => nil},
   {:dto_saving_strategy => :recursive},
  ].each do |dto_settings|
    context "with settings #{dto_settings}" do
      before :each do
        @zone = FactoryGirl.create(:zone)
        @ems  = FactoryGirl.create(:ems_cloud, :zone => @zone)

        allow(@ems.class).to receive(:ems_type).and_return(:mock)
        allow(Settings.ems_refresh).to receive(:mock).and_return(dto_settings)
      end

      context 'with empty DB' do
        before :each do
          initialize_dto_collections
        end

        it 'creates and updates a graph of DtoCollections with cycle stack -> stack' do
          # Doing 2 times, to make sure we first create all records then update all records
          2.times do
            # Fill the DtoCollections with data
            init_stack_data_with_stack_stack_cycle
            init_resource_data

            add_data_to_dto_collection(@data[:orchestration_stacks],
                                       @orchestration_stack_data_0_1,
                                       @orchestration_stack_data_0_2,
                                       @orchestration_stack_data_1_11,
                                       @orchestration_stack_data_1_12,
                                       @orchestration_stack_data_11_21,
                                       @orchestration_stack_data_12_22,
                                       @orchestration_stack_data_12_23)
            add_data_to_dto_collection(@data[:orchestration_stacks_resources],
                                       @orchestration_stack_resource_data_1_11,
                                       @orchestration_stack_resource_data_1_11_1,
                                       @orchestration_stack_resource_data_1_12,
                                       @orchestration_stack_resource_data_1_12_1,
                                       @orchestration_stack_resource_data_11_21,
                                       @orchestration_stack_resource_data_12_22,
                                       @orchestration_stack_resource_data_12_23)

            # Invoke the DtoCollections saving
            ManagerRefresh::SaveInventory.save_inventory(@ems, @data)

            # Assert saved data
            assert_full_dto_collections_graph
          end
        end

        it 'creates and updates a graph of DtoCollections with cycle stack -> resource -> stack, through resource :key' do
          # Doing 2 times, to make sure we first create all records then update all records
          2.times do
            # Fill the DtoCollections with data
            init_stack_data_with_stack_resource_stack_cycle
            init_resource_data

            add_data_to_dto_collection(@data[:orchestration_stacks],
                                       @orchestration_stack_data_0_1,
                                       @orchestration_stack_data_0_2,
                                       @orchestration_stack_data_1_11,
                                       @orchestration_stack_data_1_12,
                                       @orchestration_stack_data_11_21,
                                       @orchestration_stack_data_12_22,
                                       @orchestration_stack_data_12_23)
            add_data_to_dto_collection(@data[:orchestration_stacks_resources],
                                       @orchestration_stack_resource_data_1_11,
                                       @orchestration_stack_resource_data_1_11_1,
                                       @orchestration_stack_resource_data_1_12,
                                       @orchestration_stack_resource_data_1_12_1,
                                       @orchestration_stack_resource_data_11_21,
                                       @orchestration_stack_resource_data_12_22,
                                       @orchestration_stack_resource_data_12_23)

            # Invoke the DtoCollections saving
            ManagerRefresh::SaveInventory.save_inventory(@ems, @data)

            # Assert saved data
            assert_full_dto_collections_graph
          end
        end
      end
    end
  end

  def assert_full_dto_collections_graph
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

  def initialize_dto_collections
    # Initialize the DtoCollections
    @data                                  = {}
    @data[:orchestration_stacks]           = ::ManagerRefresh::DtoCollection.new(
      ManageIQ::Providers::CloudManager::OrchestrationStack,
      :parent      => @ems,
      :association => :orchestration_stacks)
    @data[:orchestration_stacks_resources] = ::ManagerRefresh::DtoCollection.new(
      OrchestrationStackResource,
      :parent      => @ems,
      :association => :orchestration_stacks_resources)
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
    @orchestration_stack_data_0_1   = orchestration_stack_data("0_1").merge(
      :parent => @data[:orchestration_stacks_resources].lazy_find(orchestration_stack_data("0_1")[:ems_ref],
                                                                  :key => :stack)
    )
    @orchestration_stack_data_0_2   = orchestration_stack_data("0_2").merge(
      :parent => @data[:orchestration_stacks_resources].lazy_find(orchestration_stack_data("0_2")[:ems_ref],
                                                                  :key => :stack)
    )
    @orchestration_stack_data_1_11  = orchestration_stack_data("1_11").merge(
      :parent => @data[:orchestration_stacks_resources].lazy_find(orchestration_stack_data("1_11")[:ems_ref],
                                                                  :key => :stack)
    )
    @orchestration_stack_data_1_12  = orchestration_stack_data("1_12").merge(
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
end
