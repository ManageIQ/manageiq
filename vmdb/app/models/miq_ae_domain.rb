class MiqAeDomain < MiqAeNamespace
  default_scope where(:parent_id => nil).where(arel_table[:name].not_eq("$"))
  validates_inclusion_of :parent_id, :in => [nil], :message => 'should be nil for Domain'
  after_destroy :squeeze_priorities
  default_value_for(:priority) { MiqAeDomain.highest_priority + 1 }
  default_value_for :system,  false
  default_value_for :enabled, false

  def self.enabled
    where(:enabled => true)
  end

  def self.reset_priority_by_ordered_ids(ids)
    ids.each_with_index do |id, priority|
      MiqAeDomain.where(:id => id).first.try(:update_attributes, :priority => priority + 1)
    end
  end

  def self.highest_priority
    MiqAeDomain.order('priority DESC').first.try(:priority).to_i
  end

  private

  def squeeze_priorities
    ids = MiqAeDomain.where('priority > 0').order('priority ASC').collect(&:id)
    MiqAeDomain.reset_priority_by_ordered_ids(ids)
  end

  def self.any_unlocked?
    MiqAeDomain.where('system is null OR system = ?', [false]).count > 0
  end

  def self.all_unlocked
    MiqAeDomain.where('system is null OR system = ?', [false]).order('priority DESC')
  end
end
