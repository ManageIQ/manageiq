class ImportFileUpload < ApplicationRecord
  has_one :binary_blob, :as => :resource, :dependent => :destroy

  def policy_import_data
    MiqPolicy.import_from_array(uploaded_yaml_content, :preview => true)
  end

  def service_dialog_list
    sorted_service_dialogs = uploaded_yaml_content.sort_by { |service_dialog| service_dialog["label"].downcase }
    sorted_service_dialogs.collect.with_index do |dialog, index|
      {
        :id     => index,
        :name   => dialog["label"],
        :exists => Dialog.exists?(:label => dialog["label"])
      }
    end
  end

  def widget_list
    sorted_widgets = uploaded_yaml_content.sort_by do |widget_contents|
      widget_contents["MiqWidget"]["title"].downcase
    end

    sorted_widgets.collect.with_index do |widget, index|
      {
        :id     => index,
        :name   => widget["MiqWidget"]["title"],
        :exists => MiqWidget.exists?(:title => widget["MiqWidget"]["title"])
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
end
