RSpec.describe EventStream do
  describe ".event_groups" do
    EventStream.event_groups.each do |group_name, group_data|
      (EmsEvent.group_levels + MiqEvent.group_levels).each do |level|
        group_data[level]&.each do |typ|
          it ":#{group_name}/:#{level}/#{typ} is string or regex", :providers_common => true do
            expect(typ.kind_of?(Regexp) || typ.kind_of?(String)).to eq(true)
          end

          if typ.kind_of?(Regexp)
            it ":#{group_name}/:#{level}/#{typ} is usable in SQL queries", :providers_common => true do
              expect { EventStream.where("event_type ~ ?", typ.source).to_a }
                .to_not raise_error
            end

            it ":#{group_name}/:#{level}/#{typ} only uses case insensitivity option", :providers_common => true do
              expect(typ.options & (Regexp::EXTENDED | Regexp::MULTILINE)).to eq(0)
            end
          end
        end
      end
    end
  end

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
