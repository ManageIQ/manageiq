require 'VMwareWebService/PbmService'

module MiqPbmInventory
  def pbm_initialize(server, username, password)
    @pbm_svc = PbmService.new(server, username, password) if @apiVersion >= '5.5'
  end

  def pbmProfilesByUid
    profiles = {}

    if @pbm_svc
      profile_ids = @pbm_svc.queryProfile
      @pbm_svc.retrieveContent(profile_ids).to_a.each do |pbm_profile|
        uid = pbm_profile.profileId.uniqueId

        profiles[uid] = pbm_profile
      end
    end

    profiles
  end

  def pbmQueryMatchingHub(profile_id)
    hubs = []

    if @pbm_svc
      hubs = @pbm_svc.queryMatchingHub(profile_id)
    end

    hubs
  end
end
