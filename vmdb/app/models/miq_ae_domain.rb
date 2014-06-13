class MiqAeDomain < MiqAeNamespace
  default_scope where(:parent_id => nil).where(arel_table[:name].not_eq("$"))
  validates_inclusion_of :parent_id, :in => [nil], :message => 'should be nil for Domain'

  def self.enabled
    where(:enabled => true)
  end
end
