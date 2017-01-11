module MiqAeMethodService
  class MiqAeServiceAccount < MiqAeServiceModelBase
    expose :vm_or_template, :association => true
    expose :host,           :association => true
  end
end
