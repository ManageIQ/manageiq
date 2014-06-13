module MiqAeMethodService
  class MiqAeServiceGuestDevice < MiqAeServiceModelBase
    expose :hardware, :association => true
    expose :switch,   :association => true    # pNICs link to one switch
    expose :lan,      :association => true    # vNICs link to one lan
    expose :network,  :association => true
  end
end
