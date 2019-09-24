module ManageIQ::Providers::EmbeddedAnsible::Provider::DefaultAnsibleObjects
  extend ActiveSupport::Concern

  ANSIBLE_OBJECT_SOURCE = "MIQ_ANSIBLE".freeze

  included do
    has_many :default_ansible_objects, -> { where(:source => ANSIBLE_OBJECT_SOURCE) }, :as => :resource, :dependent => :destroy, :class_name => "CustomAttribute"
  end

  def default_organization
    get_default_ansible_object("organization")
  end

  def default_credential
    get_default_ansible_object("credential")
  end

  def default_inventory
    get_default_ansible_object("inventory")
  end

  def default_host
    get_default_ansible_object("host")
  end

  def default_project
    get_default_ansible_object("project")
  end

  def default_organization=(org)
    set_default_ansible_object("organization", org)
  end

  def default_credential=(cred)
    set_default_ansible_object("credential", cred)
  end

  def default_inventory=(inv)
    set_default_ansible_object("inventory", inv)
  end

  def default_host=(host)
    set_default_ansible_object("host", host)
  end

  def default_project=(project)
    set_default_ansible_object("project", project)
  end

  def delete_ansible_object(name)
    default_ansible_objects.find_by(:name => name).try(:destroy)
  end

  private

  def get_default_ansible_object(name)
    default_ansible_objects.find_by(:name => name).try(:value).try(:to_i)
  end

  def set_default_ansible_object(name, value)
    default_ansible_objects.find_or_initialize_by(:name => name).update(:value => value)
  end
end
