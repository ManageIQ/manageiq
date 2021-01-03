RSpec.describe MiqEventDefinition do
  let(:event_defs) { MiqEventDefinition.all.group_by(&:name) }

  it "doesn't access database when unchanged model is saved" do
    m = FactoryBot.create(:miq_event_definition)
    expect { m.valid? }.not_to make_database_queries
  end

  describe "name validation" do
    it "does allow nil" do
      expect { FactoryBot.create(:miq_event_definition, :name => nil) }.not_to raise_error
    end

    it "allows alpha-numeric, underscore and hyphen characters" do
      expect { FactoryBot.create(:miq_event_definition, :name => 'valid_name-87_539_319') }
        .not_to raise_error
    end

    it "doesn't allow spaces" do
      expect { FactoryBot.create(:miq_event_definition, :name => 'invalid name') }
        .to raise_error(ActiveRecord::RecordInvalid, / Name must only contain alpha-numeric, underscore and hyphen characters without spaces/)
    end
  end

  describe '.seed_default_events' do
    context 'there are 2 event definition sets' do
      let!(:set1) { create_set!('host_operations') }
      let!(:set2) { create_set!('evm_operations') }

      context 'and CSV file with an event definition linked to one of the sets' do
        let(:csv) do
          <<-CSV.strip_heredoc
            name,description,event_type,set_type
            #
            evm_server_start,EVM Server Start,Default,host_operations
          CSV
        end

        context 'seeding default event definitions from that csv' do
          before do
            allow(File).to receive(:open).and_return(StringIO.new(csv))
            MiqEventDefinition.seed_default_events(event_defs)
          end

          it 'should create an event definition and make it a member of the set' do
            expect(MiqEventDefinition.count).to eq 1
            event_def = MiqEventDefinition.first!
            expect(event_def.memberof).to eq [set1]
          end

          context 'when the CSV was changed and the event is linked to another set now' do
            let(:csv) do
              <<-CSV.strip_heredoc
                name,description,event_type,set_type
                #
                evm_server_start,EVM Server Start,Default,evm_operations
              CSV
            end

            context 'seeding again' do
              before do
                allow(File).to receive(:open).and_return(StringIO.new(csv))
                MiqEventDefinition.seed_default_events(event_defs)
              end

              it 'should update the membership' do
                expect(MiqEventDefinition.count).to eq 1
                event_def = MiqEventDefinition.first!
                expect(event_def.memberof).to eq [set2]
              end
            end
          end
        end
      end

      def create_set!(name)
        MiqEventDefinitionSet.create!(:name => name, :description => name.humanize)
      end
    end
  end

  describe '#etype' do
    it "returns event set type" do
      set_type = 'set_testing'
      set = MiqEventDefinitionSet.create(:name => set_type, :description => "Set testing")
      event = FactoryBot.create(:miq_event_definition, :name => "vm_start")
      set.add_member(event)

      expect(event.etype.name).to eq(set_type)
    end

    it "returns nil when not belong to any event set" do
      event = FactoryBot.create(:miq_event_definition, :name => "test_event")
      expect(event.etype).to be_nil
    end
  end

  describe '.all_control_events' do
    subject { MiqEventDefinition.all_control_events }

    before do
      com_set = MiqEventDefinitionSet.create(:name => "compliance", :description => "Compliance Events")
      FactoryBot.create(:miq_event_definition,
                         :name       => "host_compliance_check",
                         :event_type => "Default").tap { |e| com_set.add_member(e) }
    end

    it 'has all default control policy events with set type' do
      event = FactoryBot.create(:miq_event_definition, :name => "some_event", :event_type => "Default")
      set   = MiqEventDefinitionSet.create(:name => "evm_operations", :description => "EVM Events")
      set.add_member(event)

      expect(subject.include?(event)).to be true
    end

    it 'has not the events for compliance policy' do
      expect(subject.any? { |e| e.name.ends_with?("compliance_check") }).to be false
    end

    it 'has not the events without a set type' do
      event = FactoryBot.create(:miq_event_definition, :name => "test_event", :event_type => "Default")
      expect(subject.include?(event)).to be false
    end
  end

  describe ".import_from_hash" do
    it "won't create an event with a definition (keyed as a string)" do
      attributes = {
        "name"        => "foo",
        "description" => "bar",
        "definition"  => {:event => {:message => "`rm -rf /super/secret/file`"}}
      }

      event, = described_class.import_from_hash(attributes)

      expect(event.definition).to be_nil
    end

    it "won't create an event with a definition (keyed as a symbol)" do
      attributes = {
        "name"        => "foo",
        "description" => "bar",
        :definition   => {:event => {:message => "`rm -rf /super/secret/file`"}},
      }

      event, = described_class.import_from_hash(attributes)

      expect(event.definition).to be_nil
    end

    context 'with defaults in db' do
      before do
        MiqEventDefinitionSet.seed
        described_class.seed_default_events(event_defs)
      end

      it "won't update an event with a definition (keyed as a string)" do
        name = described_class.first.name
        attributes = {"name" => name, "definition" => {:event => {:message => "`rm -rf /super/secret/file`"}}}

        event, = described_class.import_from_hash(attributes)

        expect(event.definition).to be_nil
      end

      it "won't update an event with a definition (keyed as a symbol)" do
        name = described_class.first.name
        attributes = {"name" => name, :definition => {:event => {:message => "`rm -rf /super/secret/file`"}}}

        event, = described_class.import_from_hash(attributes)

        expect(event.definition).to be_nil
      end
    end
  end
end
