class ClockCheckJob < ApplicationJob
  queue_as :default

  # Check for clock skew using net-ntp, and see if the skew is greater
  # than the allowable skew before raising an issue.
  #
  # The NTP check is made three times because sometimes the UDP socket
  # connection in net-ntp flakes out.
  #
  def perform(*args)
    require 'net/ntp'
    require 'attempt'

    offset = 0

    # TODO: Is there a nicer way to get the ntp server? Or is this default ok?
    attempt(tries: 3, interval: 3) do
      offset = Net::NTP.get('pool.ntp.org', 'ntp', 5).offset.abs
    end

    if offset > maximum_allowable_skew
      # TODO: What should happen here?
    end
  end

  # The maximum skew in seconds that is allowed before an issue is raised.
  #
  # TODO: Should this be a setting?
  #
  def maximum_allowable_skew
    300 # 5 minutes
  end
end
