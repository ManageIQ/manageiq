require 'VMwareWebService/PbmService'

module MiqPbmInventory
  def pbm_initialize(vim)
    begin
      # SPBM endpoint was introduced in vSphere Management SDK 5.5
      if @apiVersion < '5.5'
        $vim_log.info("MiqPbmInventory: VC version < 5.5, not connecting to SPBM endpoint")
      else
        @pbm_svc = PbmService.new(vim)
      end
    rescue => err
      $vim_log.warn("MiqPbmInventory: Failed to connect to SPBM endpoint: #{err}")
    end
  end

  def pbmProfilesByUid(_selspec = nil)
    profiles = {}
    return profiles if @pbm_svc.nil?

    begin
      profile_ids = @pbm_svc.queryProfile
      @pbm_svc.retrieveContent(profile_ids).to_a.each do |pbm_profile|
        uid = pbm_profile.profileId.uniqueId

        profiles[uid] = pbm_profile
      end
    rescue => err
      $vim_log.warn("MiqPbmInventory: pbmProfilesByUid: #{err}")
    end

    profiles
  end

  def pbmQueryMatchingHub(profile_id)
    hubs = []
    return hubs if @pbm_svc.nil?

    begin
      # If a string was passed in create a PbmProfileId object
      profile_id = RbVmomi::PBM::PbmProfileId(:uniqueId => profile_id) if profile_id.kind_of?(String)

      hubs = @pbm_svc.queryMatchingHub(profile_id)
    rescue => err
      $vim_log.warn("MiqPbmInventory: pbmQueryMatchingHub: #{err}")
    end

    hubs
  end
end
