class RemoveSystemAddSourceToMiqAeNamespace < ActiveRecord::Migration[5.0]
  class MiqAeNamespace < ActiveRecord::Base; end

  def up
    add_column :miq_ae_namespaces, :source, :string

    say_with_time('Migrating system attribute to source in MiqAeNamespace') do
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

    remove_column :miq_ae_namespaces, :system
  end

  def down
    add_column :miq_ae_namespaces, :system, :boolean

    say_with_time('Migrating source attribute to system in MiqAeNamespace') do
      MiqAeNamespace.where(:parent_id => nil).each do |obj|
        system = (obj.source == 'system' || obj.source == 'user_locked')
        obj.update_attributes!(:system => system)
      end
    end

    remove_column :miq_ae_namespaces, :source
  end
end
