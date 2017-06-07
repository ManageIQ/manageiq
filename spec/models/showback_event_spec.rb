describe ShowbackEvent do
  context "validations" do
    let(:showback_event) { FactoryGirl.build(:showback_event) }

    it "has a valid factory" do
      expect(showback_event).to be_valid
    end

    it "should ensure presence of start_time" do
      showback_event.start_time = nil
      showback_event.valid?
      expect(showback_event.errors[:start_time]).to include "can't be blank"
    end

    it "should ensure presence of end_time" do
      showback_event.end_time = nil
      showback_event.valid?
      expect(showback_event.errors[:end_time]).to include "can't be blank"
    end

    it "should fails start time is after of end time" do
      showback_event.start_time = 1.hour.ago
      showback_event.end_time = 4.hours.ago
      showback_event.valid?
      expect(showback_event.errors[:start_time]).to include "Start time should be before end time"
    end

    it "should valid if start time is equal to end time" do
      showback_event.start_time = 1.hour.ago
      showback_event.end_time = showback_event.start_time
      expect(showback_event).to be_valid
    end

    it "should ensure presence of resource" do
      showback_event.resource = nil
      expect(showback_event).not_to be_valid
    end

    it "should ensure resource exists" do
      vm = FactoryGirl.create(:vm)
      showback_event.resource = vm
      expect(showback_event).to be_valid
    end

    it 'should generate a data' do
      showback_event.data = {}
      showback_event.resource = FactoryGirl.create(:vm)
      hash = {}
      ShowbackUsageType.seed
      ShowbackUsageType.all.each do |measure_type|
        next unless showback_event.resource.type.ends_with?(measure_type.category)
        hash[measure_type.measure] = {}
        measure_type.dimensions.each do |dim|
          hash[measure_type.measure][dim] = 0
        end
      end
      showback_event.generate_data
      expect(showback_event.data).to eq(hash)
      expect(showback_event.data).not_to be_empty
      expect(showback_event.start_time).not_to eq("")
    end
  end

  context '#validate_format' do
    it 'passes validation with correct JSON data' do
      event = FactoryGirl.create(:showback_event)
      expect(event.validate_format).to be_nil
    end

    it 'fails validations with incorrect JSON data' do
      event = FactoryGirl.build(:showback_event, :data => ":-Invalid:\n-JSON")
      expect(event.validate_format).not_to be_nil
    end
  end
end