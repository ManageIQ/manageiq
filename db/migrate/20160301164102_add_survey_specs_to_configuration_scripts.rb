class AddSurveySpecsToConfigurationScripts < ActiveRecord::Migration[5.0]
  def change
    add_column :configuration_scripts, :survey_spec, :text
  end
end
