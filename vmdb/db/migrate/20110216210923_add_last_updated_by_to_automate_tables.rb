class AddLastUpdatedByToAutomateTables < ActiveRecord::Migration
  def self.up
    [:miq_ae_classes, :miq_ae_fields, :miq_ae_instances, :miq_ae_methods, :miq_ae_namespaces, :miq_ae_values].each do |tname|
      add_column    tname, :last_updated_by,         :string
      add_column    tname, :last_updated_by_user_id, :bigint
    end
  end

  def self.down
    [:miq_ae_classes, :miq_ae_fields, :miq_ae_instances, :miq_ae_methods, :miq_ae_namespaces, :miq_ae_values].each do |tname|
      remove_column tname, :last_updated_by
      remove_column tname, :last_updated_by_user_id
    end
  end
end
