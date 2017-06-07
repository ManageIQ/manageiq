class Dialog
  class ContainerTemplateServiceDialog
    def self.create_dialog(label, parameters)
      new.create_dialog(label, parameters)
    end

    # This dialog is to be used by a container template service
    def create_dialog(label, parameters)
      Dialog.new(:label => label, :buttons => "submit,cancel").tap do |dialog|
        tab = dialog.dialog_tabs.build(:display => "edit", :label => "Basic Information", :position => 0)
        add_parameters_group(tab, 0, parameters)
        dialog.save!
      end
    end

    private

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
        :required      => param.required,
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
