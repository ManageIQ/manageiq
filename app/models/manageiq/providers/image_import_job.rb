class ManageIQ::Providers::ImageImportJob < ManageIQ::Providers::AnsiblePlaybookWorkflow
  # FIXME: As of now ManageIQ supports only IBM Power Virtual Servers <--> IBM PowerVC
  # image import workflows. Future releases might not be limited only to these
  # import directions. In next release we should therefore remove dependency on the
  # AnsiblePlaybookWorkflow implementation and instead convert its contents into a module
  # including it (or not) depending on the specific workflow type.
end
