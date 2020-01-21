module ServiceOrchestration::ProvisionTagging
  DIALOG_TAG_KEY_REGEX = /^Array::dialog_tag_(?<sequence>\d*)_(?<option_key>.*)/i
  DIALOG_TAG_VALUE_REGEX = /Classification::(\d*)/

  private

  def apply_provisioning_tags
    tag_ids = provisioning_tag_ids
    return if tag_ids.empty?

    vm_ids = all_vms.collect(&:id)
    return if vm_ids.empty?

    Classification.bulk_reassignment(
      :model      => 'Vm',
      :object_ids => vm_ids,
      :add_ids    => tag_ids
    )
  end

  def provisioning_tag_ids
    provision_sequence = miq_request_task.provision_priority + 1
    dialog_options = root_service.options[:dialog] || {}

    dialog_options.flat_map do |key_name, value|
      if (match = DIALOG_TAG_KEY_REGEX.match(key_name))
        tag_sequence = match[:sequence].to_i
        value.scan(DIALOG_TAG_VALUE_REGEX).flatten if tag_sequence.zero? || tag_sequence == provision_sequence
      end
    end.compact
  end
end
