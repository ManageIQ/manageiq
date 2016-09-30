module VirtualTotalMixin
  extend ActiveSupport::Concern

  module ClassMethods
    private

    # define an attribute to calculating the total of a child
    def virtual_total(name, relation, options = {})
      virtual_aggregate(name, relation, :size, nil, options)
    end

    # define an attribute to calculating the total of a child
    #
    #  example 1:
    #
    #    class ExtManagementSystem
    #      has_many :vms
    #      virtual_total :total_vms, :vms
    #    end
    #
    #    generates:
    #
    #    def total_vms
    #      vms.count
    #    end
    #
    #    virtual_attribute :total_vms, :integer, :uses => :vms, :arel => ...
    #
    #   # arel == (SELECT COUNT(*) FROM vms where ems.id = vms.ems_id)
    #
    #  example 2:
    #
    #    class Hardware
    #      has_many :disks
    #      virtual_aggregate :allocated_disk_storage, :disks, :sum, :size
    #    end
    #
    #    generates:
    #
    #    def allocated_disk_storage
    #      if disks.loaded?
    #        disks.blank? ? nil : disks.map { |t| t.size.to_i }.sum
    #      else
    #        disks.sum(:size) || 0
    #      end
    #    end
    #
    #    virtual_attribute :allocated_disk_storage, :integer, :uses => :disks, :arel => ...
    #
    #    # arel => (SELECT sum("disks"."size") where "hardware"."id" = "disks"."hardware_id")

    def virtual_aggregate(name, relation, method_name = :sum, column = nil, options = {})
      define_virtual_aggregate_method(name, relation, method_name, column)
      reflection = reflect_on_association(relation)

      if options.key?(:arel)
        arel = options.dup.delete(:arel)
        # if there is no relation to get to the arel, have to throw it away
        arel = nil if !arel || !reflection
      else
        arel = virtual_aggregate_arel(reflection, method_name, column)
      end

      if arel
        virtual_attribute name, :integer, :uses => options[:uses] || relation, :arel => arel
      else
        virtual_attribute name, :integer, **options
      end
    end

    def define_virtual_aggregate_method(name, relation, method_name, column)
      if method_name == :size
        define_method(name) do
          (attribute_present?(name) ? self[name] : nil) || send(relation).try(:size) || 0
        end
      else
        define_method(name) do
          (attribute_present?(name) ? self[name] : nil) ||
            begin
              rel = send(relation)
              if rel.loaded?
                rel.blank? ? nil : (rel.map { |t| t.send(column).to_i } || 0).send(method_name)
              else
                # aggregates are not smart enough to handle virtual attributes
                arel_column = rel.klass.arel_attribute(column)
                rel.try(method_name, arel_column) || 0
              end
            end
        end
      end
    end

    def virtual_aggregate_arel(reflection, method_name, column)
      return unless reflection && reflection.macro == :has_many && !reflection.options[:through]
      lambda do |t|
        foreign_table = reflection.klass.arel_table
        # need db access for the keys, so delaying all this lookup until call time
        local_key = reflection.active_record_primary_key
        foreign_key = reflection.foreign_key
        arel_column = if method_name == :size
                        Arel.star.count
                      else
                        reflection.klass.arel_attribute(column).send(method_name)
                      end
        t.grouping(foreign_table.project(arel_column)
                                .where(t[local_key].eq(foreign_table[foreign_key])))
      end
    end
  end
end
