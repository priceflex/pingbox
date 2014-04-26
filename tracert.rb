# This will make a 5MB File

#fallocate -l 5M upload.file

@@current_path = "#{File.dirname(__FILE__)}"

require 's3'
require 'yaml'
require 'net/http'
require 'uri'
require 'pry'


class TraceRoute

  def initialize(ips=[])
    @output = []
    ips.each do |ip|
      @output << `traceroute #{ip} -q 1 -w 1`
    end
    @output = @output.join
    send_results
  end

  def output
    @output
  end

  def send_results
    if File.exist?("#{@@current_path}/machine.yml") && File.exist?("#{@@current_path}/test_case.yml")
      test = YAML.load(File.open("#{@@current_path}/test_case.yml"))
      machine = YAML.load(File.open("#{@@current_path}/machine.yml"))


      data = {
        :_method => :put,
        :tracer_data=> @output
      }
      begin

        postData = Net::HTTP.post_form(URI.parse("http://ping.techrockstars.com/machine/#{machine[:machine_id]}"),data)
      rescue
        puts "Error sending results"
      end

    end
  end

end

if File.exist?("#{@@current_path}/test_case.yml")
  machine_data= YAML.load(File.open("#{@@current_path}/test_case.yml"))
  if machine_data
    machine_data[:ping_hosts]
    TraceRoute.new(machine_data[:ping_hosts]).output
  end

end

