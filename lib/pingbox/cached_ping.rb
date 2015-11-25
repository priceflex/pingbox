class CachedPing

  require 'active_support/time'

  # CachedPing 
  #   - test_case_id
  #     - timestamp => ping_day
  #         -host_stat => [
  #          {
  #            host_name: 
  #            packets_loss: 
  #            total_pings:
  #            total_failed_pings: [time: , average:, :failed]
  #            total_successful_pings: [time: , average:, :failed]
  #          }]

  # This builds a hash (calculate_pings) and returns it.

  def initialize(ping_data)
    @ping_data = ping_data 
    @total_pings = 0
    @total_failed = 0
    @calculated_pings = {}
  end

  def calculate_pings
    #go through all ping results for each host and average their time
    sorted_failed_pings = @ping_data.sort_by_host(@ping_data.failed_pings)
    sorted_succcessful = @ping_data.sort_by_host(@ping_data.successful_pings)

    all_sorted_stats = @ping_data.sort_by_host(@ping_data.total_pings).map  do |a| 
      { 
        :host_name              => a[0],
        :packet_loss            => @ping_data.failed_find_by_host(a[0]).size, 
        :total_pings            => @ping_data.find_by_host_name(a[0]).size,
        :total_failed_pings     => @ping_data.sort_and_cache(@ping_data.failed_find_by_host(a[0])),
        :total_successful_pings => @ping_data.sort_and_cache(@ping_data.successful_find_by_host(a[0]))
      }
    end

    return @calcuated_pings = {
      :test_case_id => test_case_id,
      :ping_day     => ping_day.to_i,
      :host_stats   => all_sorted_stats
    }
  end

  private

  def ping_day
    # time = @ping_data.total_pings.first.time
    # time ? time : Time.now

    @ping_data.total_pings.first ? @ping_data.total_pings.first.time : Time.now
  end

  def test_case_id
    @ping_data.total_pings.first ? @ping_data.total_pings.first.test_case_id : nil
  end

end

