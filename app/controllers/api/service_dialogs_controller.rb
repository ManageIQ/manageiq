module Api
  class ServiceDialogsController < BaseController
    before_action :set_additional_attributes, :only => [:show]

    def refresh_dialog_fields_resource(type, id = nil, data = nil)
      raise BadRequestError, "Must specify an id for Reconfiguring a #{type} resource" unless id

      api_action(type, id) do |klass|
        service_dialog = resource_search(id, type, klass)
        api_log_info("Refreshing Dialog Fields for #{service_dialog_ident(service_dialog)}")

        refresh_dialog_fields_service_dialog(service_dialog, data)
      end
    end

    def create_resource(_type, _id, data)
      service_dialog = Dialog.create(data.except('content'))
      create_dialog_content(data['content'], service_dialog)
      unless service_dialog.valid?
        raise BadRequestError, "Failed to add new service dialog - #{service_dialog.errors.full_messages.join(', ')}"
      end
      service_dialog.save!
      service_dialog
    end

    private

    def set_additional_attributes
      @additional_attributes = %w(content) if attribute_selection == "all"
    end

    def refresh_dialog_fields_service_dialog(service_dialog, data)
      data ||= {}
      dialog_fields = Hash(data["dialog_fields"])
      refresh_fields = data["fields"]
      return action_result(false, "Must specify fields to refresh") if refresh_fields.blank?

      define_service_dialog_fields(service_dialog, dialog_fields)

      refresh_dialog_fields_action(service_dialog, refresh_fields, service_dialog_ident(service_dialog))
    rescue => err
      action_result(false, err.to_s)
    end

    def define_service_dialog_fields(service_dialog, dialog_fields)
      ident = service_dialog_ident(service_dialog)
      dialog_fields.each do |key, value|
        dialog_field = service_dialog.field(key)
        raise BadRequestError, "Dialog field #{key} specified does not exist in #{ident}" if dialog_field.nil?
        dialog_field.value = value
      end
    end

    def service_dialog_ident(service_dialog)
      "Service Dialog id:#{service_dialog.id} label:'#{service_dialog.label}'"
    end

    def create_dialog_content(contents, dialog)
      contents['dialog_tabs'].each { |tab_content| create_dialog_tab(tab_content, dialog) }
    end

    def create_dialog_tab(tab_content, dialog)
      DialogTab.create(tab_content.except('dialog_groups')).tap do |new_tab|
        dialog.dialog_tabs << new_tab
        tab_content['dialog_groups'].each { |group_content| create_dialog_group(group_content, new_tab) }
      end
    end

    def create_dialog_group(group_contents, tab)
      DialogGroup.create(group_contents.except('dialog_fields')).tap do |new_group|
        tab.dialog_groups << new_group
        group_contents['dialog_fields'].each { |field_contents| create_dialog_field(field_contents, new_group) }
      end
    end

    def create_dialog_field(field_contents, group)
      DialogField.create(field_contents).tap do |new_field|
        group.dialog_fields << new_field
      end
    end
  end
end
