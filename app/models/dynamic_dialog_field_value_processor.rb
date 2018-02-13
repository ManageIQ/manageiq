require 'grpc'
require 'dialog_field_services_pb'
class DynamicDialogFieldValueProcessor
  GRPC_MAPPING = {
    DialogFieldCheckBox        => :get_dialog_field_check_box,
    DialogFieldTextBox         => :get_dialog_field_text_box,
    DialogFieldTextAreaBox     => :get_dialog_field_text_area_box,
    DialogFieldSortedItem      => :get_dialog_field_sorted_item,
    DialogFieldDropDownList    => :get_dialog_field_sorted_item,
    DialogFieldDateTimeControl => :get_dialog_field_date_time_control,
    DialogFieldDateControl     => :get_dialog_field_date_control
  }

  def self.values_from_automate(dialog_field)
    new.values_from_automate(dialog_field)
  end

  def values_from_automate(dialog_field)
    attrs = dialog_field.resource_action.automate_queue_hash(
      dialog_field.dialog.try(:target_resource),
      dialog_field.dialog.try(:automate_values_hash),
      User.current_user
    )
    result = grpc_call(dialog_field, attrs)
    dialog_field.normalize_automate_values(HashWithIndifferentAccess.new(result.to_h))
  rescue => e
    $log.log_backtrace(e)

    dialog_field.script_error_values
  end

  def grpc_call(dialog_field, attributes)
    stub = Manageiq::Dialog::AutomateDialog::Stub.new('localhost:50051', :this_channel_is_insecure    )
    input = Manageiq::Dialog::Input.new
    attrs = attributes.delete(:attrs)
    attrsMap = Google::Protobuf::Map.new(:string, :string)
    attrs.each { |k, v| attrsMap[k.to_s] = v.to_s }
    attributes.each { |k, v| input[k.to_s] =  v.to_s }
    input['attrs'] = attrsMap
    stub.send(GRPC_MAPPING[dialog_field.class], input)
  end
end
