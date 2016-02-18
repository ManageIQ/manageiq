module MiqAeMethodService
  class MiqAeServiceStorageFile < MiqAeServiceModelBase
    expose :storage,                :association => true
    expose :vm_or_template,         :association => true
    expose :vm,                     :association => true
    expose :miq_template,           :association => true
  end
end
