require 'rbvmomi'
require 'rbvmomi/pbm'

class PbmService

  def initialize(server, username, password)
    vim = RbVmomi::VIM.connect(
      :host     => server,
      :insecure => true,
      :user     => username,
      :password => password
    )

    @pbm = RbVmomi::PBM.connect(vim, :insecure => true)
    @sic = @pbm.serviceContent

    @storageResourceType = RbVmomi::PBM::PbmProfileResourceType(
      :resourceType => "STORAGE"
    )

    @pbm
  end

  def queryAssociatedEntity(profileId)
    @sic.profileManager.PbmQueryAssociatedEntity(
      :profile => profileId)
  end

  def queryMatchingHub(profileId, hubsToSearch = nil)
    @sic.placementSolver.PbmQueryMatchingHub(
      :profile      => profileId,
      :hubsToSearch => hubsToSearch
    )
  end

  def queryProfile
    @sic.profileManager.PbmQueryProfile(
      :resourceType => @storageResourceType)
  end

  def retrieveContent(profileIds)
    @sic.profileManager.PbmRetrieveContent(:profileIds => profileIds)
  end
end
