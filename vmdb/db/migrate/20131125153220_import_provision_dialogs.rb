class ImportProvisionDialogs < ActiveRecord::Migration

  class MiqDialog < ActiveRecord::Base
    self.inheritance_column = :_type_disabled    # disable STI
    serialize :content
  end

  def up
    say_with_time("Import Provision dialogs") do
      # Convert v4-style provisioning dialogs from Ruby files into YAML format
      # and store in the miq_dialogs table.
      Dir.glob(Rails.root.join("db/fixtures/*.rb")) do |dialog_file|
        begin
          dialog_text = File.read(dialog_file)
          next unless dialog_text.include?('module MiqProvisionDialogs') && dialog_text.include?('def self.dialogs')

          dialog_name = File.basename(dialog_file, '.*')

          if MiqDialog.exists?(:name => dialog_name)
            say "Dialog record already exists for name:<#{dialog_name}>"
          else
            say "Importing dialog name:<#{dialog_name}>"
            load(dialog_file)
            MiqDialog.create(:name => dialog_name, :description => dialog_name, :dialog_type => 'MiqProvisionWorkflow', :content => MiqProvisionDialogs.dialogs)
            Object.send(:remove_const, :MiqProvisionDialogs)
          end
        rescue ScriptError, StandardError => err
          say  "Failed to import dialog from file <#{dialog_file}>.  Error: <#{err}>"
        end
      end
    end
  end

end
