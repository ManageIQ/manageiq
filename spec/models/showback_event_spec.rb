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

    it "should ensure presence of resource_id" do
      showback_event.resource_id = nil
      showback_event.valid?
      expect(showback_event.errors[:resource_id]).to include "can't be blank"
    end

    it "should ensure resource exists" do
      vm = FactoryGirl.create(:vm_or_template)
      showback_event.resource_type = "VmOrTemplate"
      showback_event.resource_id   = vm.id
      expect(showback_event).to be_valid
    end

    it "should fails with error resource" do
      vm = FactoryGirl.create(:vm_or_template)
      showback_event.resource_type = vm.class.name
      showback_event.resource_id   = vm.id + 100
      expect(showback_event).not_to be_valid
      expect(showback_event.errors[:resource_type]).to include "Resource should exists"
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
