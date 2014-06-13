class RemoveReservedFromAutomation < ActiveRecord::Migration
  RESERVED_CLASSES = [
    'MiqAeClass',
    'MiqAeField',
    'MiqAeInstance',
    'MiqAeMethod',
    'MiqAeNamespace',
    'MiqAeValue',
    'MiqAeWorkspace',
  ]

  # Create stub classes for all of the classes in case they don't exist in the future
  RESERVED_CLASSES.each do |c|
    klass = const_set(c, Class.new(ActiveRecord::Base))
    klass.inheritance_column = :_type_disabled  # disable STI
  end
  class Reserve < ActiveRecord::Base
    self.inheritance_column = :_type_disabled  # disable STI
  end

  def self.up
    RESERVED_CLASSES.each do |c|
      klass = const_get(c)

      recs = klass.where("reserved IS NOT NULL").all
      if recs.length > 0
        say_with_time("Migrating reserved column for #{c}") do
          recs.each do |rec|
            Reserve.create!(
              :resource_type => rec.class.name.split("::").last,
              :resource_id   => rec.id,
              :reserved      => rec.reserved
            )
          end
        end
      end

      remove_column klass.table_name.to_sym, :reserved
    end
  end

  def self.down
    RESERVED_CLASSES.each do |c|
      klass = const_get(c)
      add_column klass.table_name.to_sym, :reserved, :text
    end
  end
end
