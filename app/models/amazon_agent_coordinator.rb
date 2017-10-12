require 'yaml'
require 'open3'
require 'net/scp'
require 'linux_admin'
require 'amazon_ssa_support'

class AmazonAgentCoordinator
  include Vmdb::Logging
  attr_accessor :ems, :deploying

  # TODO: redefine these constants
  USER_NAME          = "centos".freeze
  MIQ_SSA            = "MIQ_SSA".freeze
  AGENT_RUBY_VERSION = "2.3.3".freeze
  AGENT_AMI_NAME     = "centos-7.2-hvm*".freeze

  def initialize(ems)
    @ems = ems

    # List of active agent ids
    @alive_agent_ids = []

    # List of all agent ids, include those in power off state.
    @agent_ids = []
    @deploying = false
  end

  def ec2
    @ec2 ||= ems.connect(:service => 'EC2')
  end

  def sqs
    @sqs ||= ems.connect(:service => 'SQS')
  end

  def s3
    @s3 ||= ems.connect(:service => 'S3')
  end

  def iam
    @iam ||= ems.connect(:service => 'IAM')
  end

  def agent_coordinator_settings
    @agent_coordinator_settings ||= Settings.ems.ems_amazon.agent_coordinator
  end

  def region
    @ems.provider_region
  end

  def log_level
    ll = agent_coordinator_settings.try(:log_level) || AmazonSsaSupport::DEFAULT_LOG_LEVEL
    ll.upcase
  end

  def heartbeat_prefix
    agent_coordinator_settings.try(:heartbeat_prefix) || AmazonSsaSupport::DEFAULT_HEARTBEAT_PREFIX
  end

  def heartbeat_interval
    agent_coordinator_settings.try(:heartbeat_interval) || AmazonSsaSupport::DEFAULT_HEARTBEAT_INTERVAL
  end

  def ssa_bucket
    @ssa_bucket ||= (agent_coordinator_settings.try(:bucket_prefix) || AmazonSsaSupport::DEFAULT_BUCKET_PREFIX) + '-' + @ems.guid
  end

  def request_queue
    @request_queue ||= (agent_coordinator_settings.try(:request_queue_prefix) || AmazonSsaSupport::DEFAULT_REQUEST_QUEUE) + '-' + @ems.guid
  end

  def reply_queue
    @reply_queue ||= (agent_coordinator_settings.try(:reply_queue_prefix) || AmazonSsaSupport::DEFAULT_REPLY_QUEUE) + '-' + @ems.guid
  end

  def reply_prefix
    agent_coordinator_settings.try(:reply_prefix) || AmazonSsaSupport::DEFAULT_REPLY_PREFIX
  end

  def log_prefix
    agent_coordinator_settings.try(:log_prefix) || AmazonSsaSupport::DEFAULT_LOG_PREFIX
  end

  def agent_ami
    agent_coordinator_settings.try(:agent_ami) || AGENT_AMI_NAME
  end

  def ruby_version
    agent_coordinator_settings.try(:ruby_version) || AGENT_RUBY_VERSION
  end

  def userdata_script_file
    agent_coordinator_settings.try(:userdata_script_file)
  end

  def profile_name
    MIQ_SSA
  end

  def keypair_name
    "#{MIQ_SSA}-#{@ems.guid}"
  end

  def alive_agent_ids(interval = 180)
    @alive_agent_ids = agent_ids.select { |id| agent_alive?(id, interval) }
  end

  def agent_ids
    # reset to empty
    @agent_ids = []

    bucket = s3.bucket(ssa_bucket)
    return @agent_ids unless bucket.exists?

    bucket.objects(:prefix => heartbeat_prefix).each do |obj|
      id = obj.key.split('/')[2]
      @agent_ids << id if ec2.instance(id).exists?
    end

    @agent_ids
  end

  def request_queue_empty?
    messages_in_queue(request_queue).zero?
  end

  def reply_queue_empty?
    messages_in_queue(reply_queue).zero?
  end

  def messages_in_queue(q_name)
    q = sqs.get_queue_by_name(:queue_name => q_name)
    q.attributes["ApproximateNumberOfMessages"].to_i + q.attributes["ApproximateNumberOfMessagesNotVisible"].to_i
  rescue => err
    _log.warn(err.message)
    0
  end

  def deploying?
    @deploying
  end

  def setup_agent
    agent_ids.empty? ? deploy_agent : activate_agents
  rescue => err
    _log.error("No agent is set up to prcoess requests: #{err.message}")
    _log.error(err.backtrace.join("\n"))
  end

  def activate_agents
    agent_ids.each do |id|
      agent = ec2.instance(id)
      if agent.state.name == "stopped"
        agent.start
        agent.wait_until_running
        _log.info("Agent #{id} is activated to serve requests.")
        return id
      else
        _log.warn("Agent #{id} is in abnormal state: #{agent.state.name}.")
        next
      end
    end

    _log.error("Failed to activate agents: #{agent_ids}.")
  end

  # check timestamp of heartbeat of agent_id, return true if the last beat time in
  # in the time interval
  def agent_alive?(agent_id, interval = 180)
    bucket = s3.bucket(ssa_bucket)
    return false unless bucket.exists?

    obj_id = "#{heartbeat_prefix}#{agent_id}"
    obj = bucket.object(obj_id)
    return false unless obj.exists?

    last_heartbeat = obj.last_modified
    _log.debug("#{obj.key}: Last heartbeat time stamp: #{last_heartbeat}")

    Time.now.utc - last_heartbeat < interval && ec2.instance(agent_id).state.name == "running"
  rescue => err
    _log.error("#{agent_id}: #{err.message}")
    false
  end

  def deploy_agent
    _log.info("Deploying agent ...")
    @deploying = true

    kp = get_key_pair
    security_group_id = create_security_group
    create_setting_yaml
    data = create_userdata
    zone_name = ec2.client.describe_availability_zones.availability_zones[0].zone_name
    subnets = get_subnets(zone_name)
    raise "No subnet_id is available for #{zone_name}!" if subnets.empty?
    create_profile

    instance                = ec2.create_instances(
      :image_id             => get_agent_image_id,
      :min_count            => 1,
      :max_count            => 1,
      :key_name             => kp.name,
      :security_group_ids   => [security_group_id],
      :user_data            => data,
      :instance_type        => 't2.micro',
      :placement            => {
        :availability_zone  => zone_name
      },
      :subnet_id            => subnets[0].subnet_id,
      :iam_instance_profile => {
        :name               => profile_name
      },
      :tag_specifications   => [{
        :resource_type      => "instance",
        :tags               => [{
          :key              => "Name",
          :value            => MIQ_SSA
        }]
      }]
    )
    ec2.client.wait_until(:instance_status_ok, :instance_ids => [instance[0].id])

    instance[0].id
  end

  private

  def role_exists?(role_name)
    role = iam.role(role_name)
    role.role_id
    true
  rescue ::Aws::IAM::Errors::NoSuchEntity
    false
  end

  def find_or_create_role(role_name = MIQ_SSA)
    return iam.role(role_name) if role_exists?(role_name)

    # Policy Generator:
    policy_doc     = {
      :Version     => "2012-10-17",
      :Statement   => {
        :Effect    => "Allow",
        :Principal => {
          :Service => "ec2.amazonaws.com"
        },
        :Action    => "sts:AssumeRole"
      }
    }

    role = iam.create_role(
      :role_name                   => role_name,
      :assume_role_policy_document => policy_doc.to_json
    )

    role
  end

  def create_profile(profile_name = MIQ_SSA, role_name = MIQ_SSA)
    ssa_profile = iam.instance_profile(profile_name)
    ssa_profile = iam.create_instance_profile(:instance_profile_name => profile_name) unless ssa_profile.exists?

    find_or_create_role(role_name)
    ssa_profile.add_role(:role_name => role_name) if ssa_profile.roles.empty?

    ssa_profile
  end

  def get_subnets(az)
    ec2.client.describe_subnets(
      :filters  => [{
        :name   => "availability-zone",
        :values => [az]
      }]
    ).subnets
  end

  # possible RHEL image name: values: [ "RHEL-7.3_HVM_GA*" ]
  def get_agent_image_id(image_name = agent_ami)
    imgs = ec2.client.describe_images(
      :filters  => [{
        :name   => "name",
        :values => [image_name]
      }]
    ).images

    imgs[0].image_id
  end

  def create_security_group(group_name = MIQ_SSA)
    sgs = ec2.client.describe_security_groups(
      :filters  => [{
        :name   => "group-name",
        :values => [group_name]
      }]
    ).security_groups
    return sgs[0].group_id unless sgs.empty?

    # create security group if not exist
    security_group = ec2.create_security_group(
      :group_name  => group_name,
      :description => 'Security group for MIQ SSA Agent',
      :vpc_id      => ec2.client.describe_vpcs.vpcs[0].vpc_id
    )

    security_group.authorize_ingress(
      :ip_permissions => {
        :ip_protocol  => 'tcp',
        :from_port    => 22,
        :to_port      => 22,
        :ip_ranges    => {
          :cidr_ip    => '0.0.0.0/0'
        }
      }
    )

    security_group.authorize_ingress(
      :ip_permissions => {
        :ip_protocol  => 'tcp',
        :from_port    => 80,
        :to_port      => 80,
        :ip_ranges    => {
          :cidr_ip    => '0.0.0.0/0'
        }
      }
    )

    security_group.authorize_ingress(
      :ip_permissions => {
        :ip_protocol  => 'tcp',
        :from_port    => 443,
        :to_port      => 443,
        :ip_ranges    => {
          :cidr_ip    => '0.0.0.0/0'
        }
      }
    )

    security_group.group_id
  end

  def perform_scp(local_path, remote_path, remote_instance_id, key_data)
    ip = ec2.instance(remote_instance_id).public_dns_name
    username = "centos".freeze  # This is harded coded in centos AMI image
    Net::SCP.upload!(ip, username, local_path, remote_path, :ssh => {:key_data => key_data})
  rescue => err
    _log.error(err.message)
  end

  # Get Key Pair for SSH. Create a new one if not exists.
  def get_key_pair(pair_name = keypair_name)
    kps = @ems.authentications.where(:name => pair_name)
    return kps[0] if kps.any?

    _log.info("KeyPair #{pair_name} will be created!")
    ManageIQ::Providers::CloudManager::AuthKeyPair.create_key_pair(@ems.id, :key_name => pair_name)
  end

  def create_pem_file(pair_name = keypair_name)
    kp = get_key_pair(pair_name)
    pem_file_name = "#{pair_name}.pem"
    File.write(pem_file_name, kp.auth_key)
    File.chmod(0400, pem_file_name)
    pem_file_name
  end

  def create_setting_yaml(yml = "tools/amazon_agent_settings/default_ssa_config.yml")
    defaults = agent_coordinator_settings.to_hash
    defaults[:region] = region
    defaults[:request_queue] = request_queue
    defaults[:reply_queue] = reply_queue
    defaults[:ssa_bucket] = ssa_bucket
    File.write(yml, defaults.to_yaml)
  end

  def create_userdata
    File.chmod(0755, userdata_script_file)
    stdout, stderr, status = Open3.capture3(userdata_script_file, "#{ruby_version}", "#{log_level}")

    raise "#{stderr}" unless status.exitstatus.zero?
    Base64.encode64(stdout)
  end
end
