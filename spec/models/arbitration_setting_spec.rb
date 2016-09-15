describe ArbitrationSetting do
  describe '.seed' do
    context 'seeding from YAML file' do
      before { ArbitrationSetting.seed }

      it 'should create new arbitration setting records' do
        expect(ArbitrationSetting.count).to be > 0
      end

      context 'seeding again' do
        it 'should not create new records' do
          expect { ArbitrationSetting.seed }.not_to change(ArbitrationSetting, :count)
        end
      end
    end
  end
end
