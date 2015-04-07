class HostServiceGroup < ActiveRecord::Base
  has_many :filesystems, :dependent => :nullify
  has_many :system_services, :dependent => :nullify
  belongs_to :host

  SUBCLASSES = %w(
    HostServiceGroupOpenstack
  )
end

HostServiceGroup::SUBCLASSES.each { |c| require_dependency Rails.root.join("app", "models", "#{c.underscore}.rb").to_s }
