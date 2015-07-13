module MiqAeMethodService
  class MiqAeServiceGuestApplication < MiqAeServiceModelBase
    expose :vm,                    :association => true
    expose :host,                  :association => true
  end
end
