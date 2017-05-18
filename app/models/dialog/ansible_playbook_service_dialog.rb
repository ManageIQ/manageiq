class Dialog
  class AnsiblePlaybookServiceDialog
    def self.create_dialog(label, extra_vars, hosts = 'localhost')
      new.create_dialog(label, extra_vars, hosts)
    end

    # This dialog is to be used by a playbook service
    # The job_template contains the playbook
    def create_dialog(label, extra_vars, hosts = 'localhost')
      Dialog.new(:label => label, :buttons => "submit,cancel").tap do |dialog|
        tab = dialog.dialog_tabs.build(:display => "edit", :label => "Basic Information", :position => 0)
        add_options_group(tab, 0, hosts)
        unless extra_vars.blank?
          add_variables_group(tab, 1, extra_vars)
        end
        dialog.save!
      end
    end

    private

    def add_options_group(tab, position, hosts)
      tab.dialog_groups.build(
        :display  => "edit",
        :label    => "Options",
        :position => position
      ).tap do |dialog_group|
        add_credential_dropdown(dialog_group, 0)
        add_inventory_field(dialog_group, 1, hosts)
      end
    end

    def add_credential_dropdown(group, position)
      group.dialog_fields.build(
        :type           => "DialogFieldDropDownList",
        :name           => "credential",
        :data_type      => "string",
        :dynamic        => true,
        :display        => "edit",
        :required       => false,
        :label          => "Machine Credential",
        :description    => "The credential to run the playbook",
        :reconfigurable => true,
        :position       => position,
        :dialog_group   => group
      ).tap do |dialog_field|
        dialog_field.resource_action.fqname = "AutomationManagement/AnsibleTower/Operations/Methods/Embedded_Ansible_Available_Machine_Credentials"
      end
    end

    def add_inventory_field(group, position, hosts)
      group.dialog_fields.build(
        :type           => "DialogFieldTextBox",
        :name           => "hosts",
        :description    => "A ','-separated string to list hosts for the playbook to run at",
        :data_type      => "string",
        :display        => "edit",
        :required       => false,
        :default_value  => hosts,
        :options        => {:protected => false},
        :label          => "Hosts",
        :position       => position,
        :reconfigurable => true,
        :dialog_group   => group
      )
    end

    def add_variables_group(tab, position, extra_vars)
      tab.dialog_groups.build(
        :display  => "edit",
        :label    => "Variables",
        :position => position
      ).tap do |dialog_group|
        extra_vars.transform_values { |val| val[:default] }.each_with_index do |(key, value), index|
          value = value.to_json if [Hash, Array].include?(value.class)
          add_variable_field(key, value, dialog_group, index)
        end
      end
    end

    def add_variable_field(key, value, group, position)
      group.dialog_fields.build(
        :type           => "DialogFieldTextBox",
        :name           => "param_#{key}",
        :data_type      => "string",
        :display        => "edit",
        :required       => false,
        :default_value  => value,
        :label          => key,
        :description    => key,
        :reconfigurable => true,
        :position       => position,
        :dialog_group   => group,
        :read_only      => false
      )
    end
  end
end
