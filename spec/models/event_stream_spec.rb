RSpec.describe EventStream do
  context "description" do
    it "raises NotImplementedError, for subclasses to implement" do
      expect { described_class.description }.to raise_error(NotImplementedError)
    end
  end

  context "timeline_options" do
    it "has correct structure" do
      MiqEventDefinitionSet.seed
      options = described_class.timeline_options
      expect(options.keys.sort).to eq %i[EmsEvent MiqEvent]

      expect(options[:EmsEvent].keys.sort).to eq %i[description group_levels group_names]
      expect(options[:EmsEvent][:description]).to eq(EmsEvent.description)
      expect(options[:EmsEvent][:group_levels].keys.sort).to eq %i[critical detail warning]
      expect(options[:EmsEvent][:group_levels].values.sort).to eq %w[Critical Detail Warning]
      expect(options[:EmsEvent][:group_names].keys).to include(*%i[addition configuration console deletion devices other])
      expect(options[:EmsEvent][:group_names].values).to include(*%w[Network Status Other])

      expect(options[:MiqEvent].keys.sort).to eq %i[description group_levels group_names]
      expect(options[:MiqEvent][:description]).to eq(MiqEvent.description)
      expect(options[:MiqEvent][:group_levels].keys.sort).to eq %i[detail failure success]
      expect(options[:MiqEvent][:group_levels].values.sort).to eq %w[Detail Failure Success]
      expect(options[:MiqEvent][:group_names].keys).to include(*%i[auth_validation authentication compliance container_operations ems_operations evm_operations other])
      expect(options[:MiqEvent][:group_names].values).to include(*%w[Other Compliance])
    end
  end
end
