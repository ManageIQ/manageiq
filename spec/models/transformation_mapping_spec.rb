describe TransformationMapping do
  describe '#destination' do
    let(:src) { FactoryGirl.create(:ems_cluster) }
    let(:dst) { FactoryGirl.create(:ems_cluster) }

    let(:mapping) do
      FactoryGirl.create(
        :transformation_mapping,
        :transformation_mapping_items => [TransformationMappingItem.new(:source => src, :destination => dst)]
      )
    end

    it "finds the destination" do
      expect(mapping.destination(src)).to eq(dst)
    end

    it "returns nil for unmapped source" do
      expect(mapping.destination(FactoryGirl.create(:ems_cluster))).to be_nil
    end
  end
end
