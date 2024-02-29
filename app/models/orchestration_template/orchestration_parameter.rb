class OrchestrationTemplate
  class OrchestrationParameter
    #  AWS CloudFormation data types
    #      String
    #      Number
    #      List<Number>
    #      CommaDelimitedList
    #      AWS::EC2::KeyPair::KeyName
    #      AWS::EC2::SecurityGroup::Id
    #      AWS::EC2::Subnet::Id
    #      AWS::EC2::VPC::Id
    #      List<AWS::EC2::VPC::Id>
    #      List<AWS::EC2::SecurityGroup::Id>
    #      List<AWS::EC2::Subnet::Id>
    #
    # OpenStack HOT data types
    #      string
    #      number
    #      json
    #      comma_delimited_list
    #      boolean

    attr_accessor :name, :label, :description, :data_type, :default_value, :hidden, :required, :reconfigurable
    attr_writer   :constraints

    def initialize(hash = {})
      @reconfigurable = true
      hash.each { |key, value| public_send(:"#{key}=", value) }
    end

    def constraints
      @constraints ||= []
    end

    def hidden?
      !!hidden
    end

    def required?
      !!required
    end
  end
end
