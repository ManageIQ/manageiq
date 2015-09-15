FactoryGirl.define do
  factory :authentication do
    type        "AuthUseridPassword"
    userid      "testuser"
    password    "secret"
    authtype    "default"
  end

  factory :authentication_ipmi, :parent => :authentication do
    authtype    "ipmi"
  end

  factory :authentication_ws, :parent => :authentication do
    authtype    "ws"
  end

  factory :authentication_ssh_keypair, :parent => :authentication, :class => 'ManageIQ::Providers::Openstack::InfraManager::AuthKeyPair' do
    authtype    "ssh_keypair"
    userid      "testuser"
    password    nil
    auth_key    'private_key_content'
  end

  factory :authentication_ssh_keypair_root, :parent => :authentication_ssh_keypair do
    userid      "root"
  end

  factory :authentication_ssh_keypair_without_key, :parent => :authentication_ssh_keypair do
    auth_key    nil
    status      "SomeMockedStatus"
  end
end
