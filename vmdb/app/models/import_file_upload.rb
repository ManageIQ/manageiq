class ImportFileUpload < ActiveRecord::Base
  has_one :binary_blob, :as => :resource, :dependent => :destroy

  def policy_import_data
    MiqPolicy.import_from_array(uploaded_yaml_content)
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

  def store_policy_import_data(binary_data)
    create_binary_blob(
      :binary    => binary_data,
      :name      => "Policy import",
      :data_type => "String"
    )
  end

  def store_service_dialog_import_data(binary_data)
    create_binary_blob(
      :binary    => binary_data,
      :name      => "Service Dialog import",
      :data_type => "yml"
    )
  end

  def uploaded_content
    binary_blob.binary
  end

  def uploaded_yaml_content
    YAML.load(binary_blob.binary)
  end

  private

  def determine_status(status_icon)
    case status_icon
    when "checkmark"
      "Service dialog already exists"
    when "equal-green"
      "New service dialog"
    end
  end
end
