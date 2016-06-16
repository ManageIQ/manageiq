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
      :resourceType => "STORAGE")

    @pbm
  end

  def queryProfile
    profile_ids = @sic.profileManager.PbmQueryProfile(
      :resourceType => @storageResourceType)

    @sic.profileManager.PbmRetrieveContent(:profileIds => profile_ids)
  end
end
