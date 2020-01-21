class ResourceSharer
  WHITELISTED_RESOURCE_TYPES = %w(
    VmOrTemplate
    ServiceTemplate
  ).freeze

  include ActiveModel::Model

  attr_accessor :user, :resource, :tenants, :features, :allow_tenant_inheritance

  with_options(:presence => true) do
    validates :user
    validates :resource
    validates :tenants
    validates :features
  end

  validate :allowed_resource_type
  validate :rbac_visibility
  validate :valid_tenants
  validate :allowed_features

  def self.valid_share?(share)
    new(:user     => share.user,
        :resource => share.resource,
        :tenants  => [share.tenant],
        :features => share.miq_product_features
       ).valid?
  end

  ##
  # Creates shares from the user with +features+ to +tenants+ with the given +resource+
  # @param user - The user sharing the resource
  # @param resource - The resource to be shared
  # @param tenants - The tenants to share the resource with
  # @param features - The product features to be associated with the share. Features must
  #   be a subset of the user's accessible miq_product_features or :all if you wish to
  #   share all the user's accessible features. Defaults to :all.
  def initialize(args = {})
    args = args.reverse_merge(:features => :all)
    if args[:user] && args[:features] == :all
      args[:features] = args[:user].miq_user_role.miq_product_features
    end
    args[:allow_tenant_inheritance] = !!args[:allow_tenant_inheritance]
    super
  end

  def share
    return false unless valid?

    ActiveRecord::Base.transaction do
      tenants.map do |tenant|
        Share.create!(:user                     => user,
                      :resource                 => resource,
                      :tenant                   => tenant,
                      :miq_product_features     => features,
                      :allow_tenant_inheritance => allow_tenant_inheritance)
      end
    end
  end

  private

  def rbac_visibility
    return unless user && resource
    unless Rbac::Filterer.filtered_object(resource, :user => user).present?
      errors.add(:user, "is not authorized to share this resource")
    end
  end

  def allowed_features
    return unless user && features

    rejected_features = []

    # TODO:  This is bad. Need feature API to fetch Set of allowed features
    # based on parent and check if the requested features are all in the Set.
    Array(features).each do |feature|
      unless user.miq_user_role.allows?(:identifier => feature.identifier)
        rejected_features << "#{feature.identifier}: #{feature.name}"
      end
    end

    unless rejected_features.empty?
      errors.add(:features, "not permitted to be shared by user ##{user.id}: #{rejected_features.join(', ')}")
    end
  end

  def allowed_resource_type
    unless WHITELISTED_RESOURCE_TYPES.any? { |type| resource.kind_of?(type.constantize) }
      errors.add(:resource, "is not sharable. Supported resource types: #{WHITELISTED_RESOURCE_TYPES.join(' ')}")
    end
  end

  def valid_tenants
    return unless tenants
    unless tenants.respond_to?(:all?) && tenants.all? { |t| t.kind_of?(Tenant) }
      errors.add(:tenants, "must be an array of Tenant objects")
    end
  end
end
