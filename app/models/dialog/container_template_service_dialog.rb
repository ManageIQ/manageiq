class Dialog
  class ContainerTemplateServiceDialog
    def self.create_dialog(name, parameters)
      new.create_dialog(name, parameters)
    end

    # This dialog is to be used by a container template service
    def create_dialog(name, parameters)
      Dialog.new(:name => name, :buttons => "submit,cancel").tap do |dialog|
        tab = dialog.dialog_tabs.build(:display => "edit", :label => "Basic Information", :position => 0)
        add_options_group(tab, 0)
        add_parameters_group(tab, 1, parameters)
        dialog.save!
      end
    end

    private

    def add_options_group(tab, position)
      tab.dialog_groups.build(
        :display  => "edit",
        :label    => "Options",
        :position => position
      ).tap do |dialog_group|
        add_project_dropdown(dialog_group, 0)
        add_project_textbox(dialog_group, 1)
      end
    end

    def add_project_dropdown(group, position)
      group.dialog_fields.build(
        :type         => "DialogFieldDropDownList",
        :name         => "existing_project_name",
        :data_type    => "string",
        :dynamic      => true,
        :display      => "edit",
        :label        => "Add To Existing Project",
        :description  => "The desired existing project for the provisioning",
        :position     => position,
        :dialog_group => group
      ).tap do |dialog_field|
        dialog_field.resource_action.fqname = "Container/Openshift/Operations/Methods/Available_Projects"
      end
    end

    def add_project_textbox(group, position)
      group.dialog_fields.build(
        :type         => "DialogFieldTextBox",
        :name         => "new_project_name",
        :data_type    => "string",
        :display      => "edit",
        :label        => "(or) Add To New Project",
        :description  => "The desired new project for the provisioning",
        :position     => position,
        :dialog_group => group
      )
    end

    def add_parameters_group(tab, position, parameters)
      tab.dialog_groups.build(
        :display  => "edit",
        :label    => "Parameters",
        :position => position
      ).tap do |dialog_group|
        parameters.each_with_index do |param, index|
          add_parameter_field(param, dialog_group, index)
        end
      end
    end

    def add_parameter_field(param, group, position)
      options = {
        :type          => "DialogFieldTextBox",
        :name          => "param_#{param.name}",
        :data_type     => "string",
        :display       => "edit",
        :required      => param.required && param.generate.blank?,
        :default_value => param.value,
        :label         => param.name.tr("_", " ").titleize,
        :description   => param.description,
        :position      => position,
        :dialog_group  => group
      }
      options[:label] += " (Auto-generated if empty)" if param.generate == 'expression'

      group.dialog_fields.build(options)
    end
  end
end
