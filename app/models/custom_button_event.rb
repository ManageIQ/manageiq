class CustomButtonEvent < EventStream
  virtual_column :button_name, :type => :string
  virtual_column :automate_entry_point, :type => :string

  def automate_entry_point
    full_data[:automate_entry_point].to_s
  end

  def button_name
    CustomButton.find_by(:id => full_data[:button_id])&.name || full_data[:button_name].to_s
  end
end
