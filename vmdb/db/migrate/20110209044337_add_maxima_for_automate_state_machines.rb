class AddMaximaForAutomateStateMachines < ActiveRecord::Migration
  def self.up
    # Class Level
    add_column    :miq_ae_fields, :max_retries, :string
    add_column    :miq_ae_fields, :max_time,    :string

    # Instance Level
    add_column    :miq_ae_values, :max_retries, :string
    add_column    :miq_ae_values, :max_time,    :string
  end

  def self.down
    # Class Level
    remove_column :miq_ae_fields, :max_retries
    remove_column :miq_ae_fields, :max_time

    # Instance Level
    remove_column :miq_ae_values, :max_retries
    remove_column :miq_ae_values, :max_time
  end
end
