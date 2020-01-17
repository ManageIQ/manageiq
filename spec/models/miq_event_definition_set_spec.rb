RSpec.describe MiqEventDefinitionSet do
  describe ".seed" do
    context 'seeding from a csv file' do
      before { MiqEventDefinitionSet.seed }

      it 'should create new definition sets' do
        expect(MiqEventDefinitionSet.count).to be > 0
      end

      context 'seeding again' do
        it 'should not create new records' do
          expect { MiqEventDefinitionSet.seed }.not_to change(MiqEventDefinitionSet, :count)
        end
      end
    end
  end
end
