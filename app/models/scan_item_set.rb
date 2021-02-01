class ScanItemSet < MiqSet
  def self.display_name(number = 1)
    n_('Analysis Profile', 'Analysis Profiles', number)
  end
end
