class ResourceSharer
  WHITELISTED_RESOURCE_TYPES = %w(
    MiqTemplate
    ServiceTemplate
  ).freeze

  include ActiveModel::Model

  attr_accessor :user, :resource, :tenants, :features

  with_options :presence => true do
    validates :user
    validates :resource
    validates :tenants
    validates :features
  end

  validate :allowed_resource_type
  validate :rbac_visibility
  validate :valid_tenants

  ##
  # Creates shares from the user with +features+ to +tenants+ with the given +resource+
  # @param user - The user sharing the resource
  # @param resource - The resource to be shared
  # @param tenants - The tenants to share the resource with
  # @param features - The product features to be associated with the share. Features must
  #   be a subset of the user's accessible miq_product_features or :all if you wish to
  #   share all the user's accessible features. Defaults to :all.
  def initialize(args={})
    args = args.reverse_merge(:features => :all)
    if args[:user] && args[:features] == :all
      args[:features] = args[:user].miq_user_role.miq_product_features
    end
    super
  end

  def share
    return false unless valid?

    ActiveRecord::Base.transaction do
      tenants.map do |tenant|
        Share.create!(:user => user, :resource => resource, :tenant => tenant, :miq_product_features => features)
      end
    end
  end

  private

  def rbac_visibility
    return unless user && resource
    unless Rbac::Filterer.search(:targets => [resource], :user => user)[0].include?(resource)
      errors.add(:user, "is not authorized to share this resource")
    end
  end

  def allowed_resource_type
    unless WHITELISTED_RESOURCE_TYPES.any? { |type| resource.is_a?(type.constantize) }
      errors.add(:resource, "is not sharable. Supported resource types: #{WHITELISTED_RESOURCE_TYPES.join(' ')}")
    end
  end

  def valid_tenants
    return unless tenants
    unless tenants.respond_to?(:all?) && tenants.all? { |t| t.is_a?(Tenant) }
      errors.add(:tenants, "must be an array of Tenant objects")
    end
  end
end
