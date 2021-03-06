$pingbox_root = "#{File.dirname(__FILE__)}/../.." unless $pingbox_root

require 'net/http'
require 'xmlsimple'
require "#{$pingbox_root}/lib/ping/ping"
require "#{$pingbox_root}/lib/machine"

class EventLogger

  def self.process_exception(process, exception)
    puts "Unexpected error in #{process.downcase} process:\n#{exception.message}"

    backtrace = []
    unless exception.message.include? "Connection refused"
      exception.backtrace.each do |m| 
        puts "\tfrom #{m}"
        backtrace <<  m.gsub(/</, '{').gsub(/>/, '}')
      end
    end

    event_data = {
      machine_info:     Machine.html_info,
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

  rescue => e
    puts "Cannot send error - #{e.message}"
  end

end
