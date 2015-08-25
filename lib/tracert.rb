$pingbox_root = "#{File.dirname(__FILE__)}/../.." unless $pingbox_root
$config_dir = "#{$pingbox_root}/config"

require 'ping/ping'
require 'yaml'
require 'net/http'
require 'uri'
require 'pry'

class TraceRoute

  attr_accessor :results, :ips

  def initialize(ips=[])
    @ips = ips
  end

  def trace
    output = []

    @ips.each do |ip| 
      print "Getting traceroute for #{ip}... "
      output << `traceroute #{ip} -q 1 -w 1`
      puts "done."
    end

    @results = output.join
  end

  def send_results
    puts "Sending traceroute results..."

    if File.exist?("#{$config_dir}/machine.yml") && File.exist?("#{$config_dir}/test_case.yml")
      machine = YAML.load(File.open("#{$config_dir}/machine.yml"))
      url = Ping.env? == :production ? "ping.techrockstars.com" : "192.168.0.124:3000"
      machine_url = "http://#{url}/machine/#{machine[:machine_id]}"
      data = { :_method => :put, :tracer_data => @results }

      Net::HTTP.post_form(URI.parse(machine_url), data) 
      puts "Successfully sent traceroute data to #{machine_url}"
    else 
      return puts "Machine/Test Case configuration files not found.  Exiting."
    end

  rescue Exception => e
    puts "Error sending traceroute results: #{e.message}"
    e.backtrace.each { |m| puts "\tfrom #{m}" }
  end

end

if File.exist?("#{$config_dir}/test_case.yml")
  machine_data = YAML.load(File.open("#{$config_dir}/test_case.yml"))

  if machine_data
    t = TraceRoute.new(machine_data[:ping_hosts])
    t.trace
    t.send_results
  end
end
