class ImportFileUpload < ActiveRecord::Base
  has_one :binary_blob, :as => :resource, :dependent => :destroy

  def policy_import_data
    MiqPolicy.import_from_array(uploaded_yaml_content, :preview => true)
  end

  def service_dialog_json
    sorted_service_dialogs = uploaded_yaml_content.sort_by { |service_dialog| service_dialog["label"].downcase }
    service_dialogs = sorted_service_dialogs.collect.with_index do |dialog, index|
      status_icon = Dialog.exists?(:label => dialog["label"]) ? "checkmark" : "equal-green"
      status = determine_status(status_icon)

      {
        :id          => index,
        :name        => dialog["label"],
        :status_icon => status_icon,
        :status      => status
      }
    end

    service_dialogs.to_json
  end

  def widget_json
    sorted_widgets = uploaded_yaml_content.sort_by do |widget_contents|
      widget_contents["MiqWidget"]["title"].downcase
    end

    widgets = sorted_widgets.collect.with_index do |widget, index|
      status_icon = MiqWidget.exists?(:title => widget["MiqWidget"]["title"]) ? "checkmark" : "equal-green"
      status = determine_status(status_icon)

      {
        :id          => index,
        :name        => widget["MiqWidget"]["title"],
        :status_icon => status_icon,
        :status      => status
      }
    end

    widgets.to_json
  end

  def store_policy_import_data(binary_data)
    store_binary_data(binary_data, "Policy import")
  end

  def store_service_dialog_import_data(binary_data)
    store_binary_data(binary_data, "Service Dialog import")
  end

  def store_widget_import_data(binary_data)
    store_binary_data(binary_data, "Widget import")
  end

  def uploaded_content
    binary_blob.binary
  end

  def uploaded_yaml_content
    YAML.load(binary_blob.binary)
  end

  private

  def store_binary_data(binary_data, name)
    create_binary_blob(
      :binary    => binary_data,
      :name      => name,
      :data_type => "yml"
    )
  end

  def determine_status(status_icon)
    case status_icon
    when "checkmark"
      "This object already exists in the database with the same name"
    when "equal-green"
      "New object"
    end
  end
end
