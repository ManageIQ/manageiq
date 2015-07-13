class RenameLastUpdatedByFieldsInAutomate < ActiveRecord::Migration
  def self.up
    [:miq_ae_classes, :miq_ae_fields, :miq_ae_instances, :miq_ae_methods, :miq_ae_namespaces, :miq_ae_values].each do |tname|
      rename_column tname, :last_updated_by,         :updated_by
      rename_column tname, :last_updated_by_user_id, :updated_by_user_id
    end
  end

  def self.down
    [:miq_ae_classes, :miq_ae_fields, :miq_ae_instances, :miq_ae_methods, :miq_ae_namespaces, :miq_ae_values].each do |tname|
      rename_column tname, :updated_by,         :last_updated_by
      rename_column tname, :updated_by_user_id, :last_updated_by_user_id
    end
  end
end
