$pingbox_root = "#{File.dirname(__FILE__)}/.." unless $pingbox_root
$config_dir = "#{$pingbox_root}/config"

require 'yaml'
require 'uri'
require 'pry'
require 'net/http'
require "#{$pingbox_root}/lib/ping/ping"
require "#{$pingbox_root}/lib/pingbox/event_logger"

class TraceRoute

  attr_accessor :results, :ips

  def initialize(ips = [])
    @ips = ips
  end

  def trace
    output = []

    @ips.each do |ip| 
      puts "Getting traceroute for #{ip}... "
      output << `traceroute #{ip} -q 1 -w 1`
    end

    @results = output.join
  end

  def send_results
    puts "Sending traceroute results..."

    if File.exist?("#{$config_dir}/machine.yml") && File.exist?("#{$config_dir}/test_case.yml")
      machine = YAML.load(File.open("#{$config_dir}/machine.yml"))
      url = Ping.env? == :production ? "ping.techrockstars.com" : "techrockstars.com:3000"
      machine_url = "http://#{url}/machine/#{machine[:machine_id]}"
      data = { :_method => :put, :tracer_data => @results }

      Net::HTTP.post_form(URI.parse(machine_url), data) 
      puts "Successfully sent traceroute data to #{machine_url}"
    else 
      return puts "Machine/Test Case configuration files not found for traceroute. Abort."
    end
  end

end

begin
  if File.exist?("#{$config_dir}/test_case.yml")
    machine_data = YAML.load(File.open("#{$config_dir}/test_case.yml"))

    puts "Begin traceroute."

    if machine_data[:ping_hosts]
      @traceroute = TraceRoute.new(machine_data[:ping_hosts])
      @traceroute.trace
      @traceroute.send_results
    else
      puts "No hosts to trace.\n\n"
    end
  end
rescue Exception => e
  EventLogger.process_exception("Traceroute", e)
  exit 1
end
