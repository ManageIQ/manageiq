class ShareRevalidator
  def self.revalidate(model)
    public_send("revalidate_#{model.class.name}", model)
  end

  def self.revalidate_MiqUserRole(role)
    Share.joins(:user => :miq_groups).where(:miq_groups => {:id => role.miq_groups}).each do |share|
      share.destroy unless ResourceSharer.valid_share?(share)
    end
  end
end
