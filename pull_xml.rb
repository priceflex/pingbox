require 'net/http'
require 'xmlsimple'
require 'ap'

url = "http://localhost:3000/machine/1361781826/test_cases.xml"
xml_data = Net::HTTP.get_response(URI.parse(url)).body

ap  data = XmlSimple.xml_in(xml_data)

ap @test_case_id = data["id"][0]["content"].to_i
ap @ping_hosts =  data["ping-hosts-addresses"][0].split("\n")
ap @ping_times =  (60  / 3) / @ping_hosts.size
