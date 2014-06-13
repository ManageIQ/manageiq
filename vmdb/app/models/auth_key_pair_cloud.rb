class AuthKeyPairCloud < AuthPrivateKey
  SUBCLASSES = [
    "AuthKeyPairAmazon",
    "AuthKeyPairOpenstack",
  ]

  has_and_belongs_to_many :vms, :join_table => :key_pairs_vms, :foreign_key => :authentication_id
end

# Preload any subclasses of this class, so that they will be part of the
#   conditions that are generated on queries against this class.
AuthKeyPairCloud::SUBCLASSES.each { |c| require_dependency Rails.root.join("app", "models", "#{c.underscore}.rb").to_s }
