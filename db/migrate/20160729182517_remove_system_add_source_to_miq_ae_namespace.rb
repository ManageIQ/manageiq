class RemoveSystemAddSourceToMiqAeNamespace < ActiveRecord::Migration[5.0]
  class MiqAeNamespace < ActiveRecord::Base; end

  def up
    say_with_time('Adding source to MiqAeNamespace') do
      add_column :miq_ae_namespaces, :source, :string
    end

    say_with_time('Migrating System attribute to Source in MiqAeNamespace') do
      MiqAeNamespace.where(:parent_id => nil).each do |obj|
        source = if obj.name == 'ManageIQ'
                   'system'
                 elsif obj.system
                   'user_locked'
                 else
                   'user'
                 end
        obj.update_attributes!(:source => source)
      end
    end

    say_with_time('Removing system from MiqAeNamespace') do
      remove_column :miq_ae_namespaces, :system
    end
  end

  def down
    say_with_time('Adding system to MiqAeNamespace') do
      add_column :miq_ae_namespaces, :system, :boolean
    end

    say_with_time('Migrating Source attribute to System in MiqAeNamespace') do
      MiqAeNamespace.where(:parent_id => nil).each do |obj|
        system = (obj.source == 'system' || obj.source == 'user_locked')
        obj.update_attributes!(:system => system)
      end
    end

    say_with_time('Removing source from MiqAeNamespace') do
      remove_column :miq_ae_namespaces, :source
    end
  end
end
