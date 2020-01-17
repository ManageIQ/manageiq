RSpec.describe CustomButtonEvent do
  let(:custom_button) { FactoryBot.create(:custom_button, :applies_to_class => "Vm", :name => "Test Button") }
  let(:ae_entry_point) { "/SYSTEM/PROCESS/Request" }
  let(:cb_event) do
    FactoryBot.create(:custom_button_event,
                       :full_data => {
                         :automate_entry_point => ae_entry_point,
                         :button_id            => custom_button.id,
                         :button_name          => custom_button.name
                       })
  end

  context '#automate_entry_point' do
    it 'returns a string' do
      expect(cb_event.automate_entry_point).to eq(ae_entry_point)
    end

    it 'returns an empty string' do
      cb_event.full_data.delete(:automate_entry_point)
      cb_event.save!

      expect(cb_event.automate_entry_point).to eq("")
    end
  end

  context '#button_name' do
    it "returns button's current name" do
      expect(cb_event.button_name).to eq("Test Button")

      custom_button.update(:name => "New Button Name")
      expect(cb_event.button_name).to eq("New Button Name")
    end

    it 'returns button name from event data' do
      cb_event.full_data[:button_id] = custom_button.id - 1
      cb_event.save!
      custom_button.update(:name => "New Button Name")

      expect(cb_event.button_name).to eq("Test Button")
    end
  end
end
