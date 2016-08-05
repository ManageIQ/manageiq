require 'rbvmomi'
require 'rbvmomi/pbm'

PbmVimConnection = Struct.new(:host, :cookie)

class PbmService
  def initialize(vim)
    # RbVmomi::PBM#connect expects a RbVmomi::VIM object, use a struct
    # to fake it out into using our vim Handsoap connection
    pbm_vim_conn = PbmVimConnection.new(vim.server.dup, vim.session_cookie.dup)

    @pbm = RbVmomi::PBM.connect(pbm_vim_conn, :insecure => true)
    @sic = @pbm.serviceContent
  end

  def queryAssociatedEntity(profileId)
    @sic.profileManager.PbmQueryAssociatedEntity(:profile => profileId)
  end

  def queryMatchingHub(profileId, hubsToSearch = nil)
    @sic.placementSolver.PbmQueryMatchingHub(
      :profile      => profileId,
      :hubsToSearch => hubsToSearch
    )
  end

  def queryProfile
    @sic.profileManager.PbmQueryProfile(
      :resourceType => RbVmomi::PBM::PbmProfileResourceType(:resourceType => "STORAGE")
    )
  end

  def retrieveContent(profileIds)
    @sic.profileManager.PbmRetrieveContent(:profileIds => profileIds)
  end
end
