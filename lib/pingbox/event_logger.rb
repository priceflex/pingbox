$pingbox_root = "#{File.dirname(__FILE__)}/.." unless $pingbox_root

require "#{$pingbox_root}/lib/ping/ping"

class EventLogger

  def self.process_exception(process, exception)
    puts "Unexpected error in #{process.downcase} process:\n#{exception.message}"

    backtrace = []
    exception.backtrace.each do |m| 
      puts "\tfrom #{m}"
      backtrace <<  m.gsub(/</, '{').gsub(/>/, '}')
    end

    event_data = {
      event:            process,
      event_message:    exception.message.gsub(/</, '{').gsub(/>/, '}'),
      event_backtrace:  "<br />#{backtrace.join('<br />')}"
    }

    url = Ping.server_url

    # send the error to the proper server for event logging.
    post_data = Net::HTTP.post_form(URI.parse("#{url}/log_event"), event_data)

    if post_data.code == "200" 
      puts "\nSuccessfully sent #{process.downcase} error to #{url}/log_event\n\n"
    else
      puts "\n#{process.capitalize} error message did not successfully send. Server gave a response of #{post_data.code}.\n\n"
    end
  end

end
