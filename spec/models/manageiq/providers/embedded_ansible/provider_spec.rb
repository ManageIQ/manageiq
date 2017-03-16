require 'support/ansible_shared/provider'

describe ManageIQ::Providers::EmbeddedAnsible::Provider do
  it_behaves_like 'ansible provider'
end
