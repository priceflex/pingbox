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

      postData = Net::HTTP.post_form(URI.parse("http://wc.d.techrockstars.com:3000/machine/#{machine[:machine_id]}"),data)

    end
  end

end

route = TraceRoute.new(["google.com", "wc.d.techrockstars.com"]).output
puts route

