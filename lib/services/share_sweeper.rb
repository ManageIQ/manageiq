class ShareSweeper
  def self.sweep(model)
    public_send("sweep_after_change_to_#{model.class.name}", model)
  end

  def self.sweep_after_change_to_MiqUserRole(role)
    Share.joins(:user => :miq_groups).where(:miq_groups => {:id => role.miq_groups}).each do |share|
      share.destroy unless ResourceSharer.valid_share?(share)
    end
  end

  def self.sweep_after_change_to_User(user)
    Share.joins(:user).where(:user => user).each do |share|
      share.destroy unless ResourceSharer.valid_share?(share)
    end
  end
end
