module MiqServerBaseConstants
  RUN_AT_STARTUP = %w(MiqRegion MiqWorker MiqQueue MiqReportResult).freeze

  STATUS_STARTING       = 'starting'.freeze
  STATUS_STARTED        = 'started'.freeze
  STATUS_RESTARTING     = 'restarting'.freeze
  STATUS_STOPPED        = 'stopped'.freeze
  STATUS_QUIESCE        = 'quiesce'.freeze
  STATUS_NOT_RESPONDING = 'not responding'.freeze
  STATUS_KILLED         = 'killed'.freeze

  STATUSES_STOPPED = [STATUS_STOPPED, STATUS_KILLED].freeze
  STATUSES_ACTIVE  = [STATUS_STARTING, STATUS_STARTED].freeze
  STATUSES_ALIVE   = STATUSES_ACTIVE + [STATUS_RESTARTING, STATUS_QUIESCE].freeze

  RESTART_EXIT_STATUS = 123
end
