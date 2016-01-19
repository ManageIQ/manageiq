describe MiqEventDefinition do
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
            MiqEventDefinition.seed_default_events
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
                MiqEventDefinition.seed_default_events
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
end
