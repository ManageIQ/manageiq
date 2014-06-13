require 'Amazon/amazon_connection'

class AmazonIam

  def self.iam_connect(access_key_id, secret_access_key)
    AmazonConnection.raw_connect(access_key_id, secret_access_key, "IAM")
  end

  def self.iam_for_aws_user(access_key_id, secret_access_key)
    AmazonConnection.verify_credentials(access_key_id, secret_access_key)
    iam = self.iam_connect(access_key_id, secret_access_key)
    if self.is_iam_user?(iam)
      # FIXME: this is probably the wrong error category to raise
      raise MiqException::MiqHostError, "Access key #{access_key_id} belongs to IAM user, not to the AWS account holder."
    end
    iam
  end

  # if aws_user is supplied, verify that this iam user belongs to that
  # account
  def self.verify_iam_user(access_key_id, secret_access_key, aws_user_iam=nil)
    AmazonConnection.verify_credentials(access_key_id, secret_access_key)
    iam = self.iam_connect(access_key_id, secret_access_key)
    unless self.is_iam_user?(iam)
      # FIXME: this is probably the wrong error category to raise
      raise MiqException::MiqHostError, "Access key #{access_key_id} belongs to the AWS account holder, not to an IAM user."
    end
    if aws_user_iam
      self.iam_user_for_access_key(aws_user_iam, access_key_id)
    end
    true
  end

  def self.iam_user_for_access_key(iam, access_key_id)
    iam.users.each do |user|
      user.access_keys.each do |access_key|
        return user if access_key.id == access_key_id
      end
    end
    raise MiqException::MiqHostError, "Access key #{access_key_id} does not match an IAM user for aws account holder."
  end

  private
  def self.is_iam_user?(iam)
    begin
      name = iam.client.get_user[:user][:user_name]
    rescue AWS::IAM::Errors::AccessDenied => e
      return true
    end
    # for AWS user, name will be nil, for IAM user, there will be a
    # name (if user has user/group management permissions), or
    # get_user will throw an exception (for less-privileged users)
    return !name.nil?
  end

end
