class ImportFileUpload < ApplicationRecord
  has_one :binary_blob, :as => :resource, :dependent => :destroy

  def policy_import_data
    MiqPolicy.import_from_array(uploaded_yaml_content, :preview => true)
  end

  def service_dialog_list
    sorted_service_dialogs = uploaded_yaml_content.sort_by { |service_dialog| service_dialog["label"].downcase }
    sorted_service_dialogs.collect.with_index do |dialog, index|
      status_icon = Dialog.exists?(:label => dialog["label"]) ? "checkmark" : "equal-green"
      status = determine_status(status_icon)

      {
        :id          => index,
        :name        => dialog["label"],
        :status_icon => ActionController::Base.helpers.image_path("16/#{status_icon}.png"),
        :status      => status
      }
    end
  end

  def widget_list
    sorted_widgets = uploaded_yaml_content.sort_by do |widget_contents|
      widget_contents["MiqWidget"]["title"].downcase
    end

    sorted_widgets.collect.with_index do |widget, index|
      status_icon = MiqWidget.exists?(:title => widget["MiqWidget"]["title"]) ? "checkmark" : "equal-green"
      status = determine_status(status_icon)

      {
        :id          => index,
        :name        => widget["MiqWidget"]["title"],
        :status_icon => ActionController::Base.helpers.image_path("16/#{status_icon}.png"),
        :status      => status
      }
    end
  end

  def store_binary_data_as_yml(binary_data, name)
    create_binary_blob(
      :binary    => binary_data,
      :name      => name,
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
      _("This object already exists in the database with the same name")
    when "equal-green"
      _("New object")
    end
  end
end
