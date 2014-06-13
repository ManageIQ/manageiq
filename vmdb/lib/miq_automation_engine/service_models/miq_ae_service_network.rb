module MiqAeMethodService
  class MiqAeServiceNetwork < MiqAeServiceModelBase
    expose :hardware,     :association => true
    expose :guest_device, :association => true
  end
end
