module ArCountMixin
  extend ActiveSupport::Concern
  included do
    # Add virtual columns for has_many counts for reporting
    self.reflections_with_virtual.each do |k, v|
      next unless v.macro == :has_many || v.macro == :has_and_belongs_to_many
      m = "#{k}_count"
      define_method(m) { self.send(k).size }
      virtual_column m, :type => :integer, :uses => k
    end
  end
end
