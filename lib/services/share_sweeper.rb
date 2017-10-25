class ShareSweeper
  def self.sweep(model)
    new(model).sweep
  end

  attr_reader :model

  def initialize(model)
    @model = model
  end

  def sweep
    public_send("sweep_after_change_to_#{model.class.name}", model)
  end

  def sweep_after_change_to_MiqUserRole(role)
    Share.joins(:user => :miq_groups).where(:miq_groups => {:id => role.miq_groups}).each(&method(:sweep_share))
  end

  def sweep_after_change_to_Entitlement(entitlement)
    Share.joins(:user => :miq_groups).where(:miq_groups => {:id => entitlement.miq_group}).each(&method(:sweep_share))
  end

  private

  def sweep_share(share)
    share.destroy unless ResourceSharer.valid_share?(share)
  end
end
