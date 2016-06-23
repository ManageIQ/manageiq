module VirtualTotalMixin
  extend ActiveSupport::Concern

  module ClassMethods
    private

    # define an attribute to calculating the total of a child
    #   virtual_total :total_vms, :vms
    #
    #   def total_vms
    #     vms.count
    #   end
    #   virtual_attribute :total_vms, :integer, :uses => :vms
    #
    #   It also defines the necessary arel so it will sort by the total in the database
    #
    def virtual_total(name, relation, options = {})
      define_method(name) do
        send(relation).try(:size) || 0
      end

      reflection = reflect_on_association(relation)

      if options.key?(:arel)
        arel = options.dup.delete(:arel)
        arel = nil if !arel || !reflection
      elsif reflection && reflection.macro == :has_many && !reflection.options[:through]
        arel = lambda do |t|
          foreign_table = reflection.klass.arel_table
          # need db access for the keys, so delaying all this lookup until call time
          local_key = reflection.active_record_primary_key
          foreign_key = reflection.foreign_key
          # assuming has_many
          Arel::Nodes::Grouping.new(foreign_table.project(Arel.star.count)
                                                 .where(t[local_key].eq(foreign_table[foreign_key])))
        end
      end

      if arel
        virtual_attribute name, :integer, :uses => options[:uses] || relation, :arel => arel
      else
        virtual_attribute name, :integer, **options
      end
    end
  end
end
