#!/usr/bin/env ruby
require 'rubygems'
require 'yaml'
File_Config    = File.join(File.dirname(__FILE__), 'config', 'config.yml')
ResetTimes     = {:down => 4000,
                  :left => 9000}
MaxPerRotation = 3000

class BuildPunisher
  attr_accessor :config
  
  def initialize
    @config = YAML.load_file(File_Config)
  end

  def retrieve_xml
    puts "=== So whos been naughty then? ..."
    url = URI.parse(@config["bamboo"]["failed_rss_url"])
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    req = Net::HTTP::Get.new(url.path + "?" + url.query)
    req.basic_auth @config["bamboo"]["username"], @config["bamboo"]["password"]
    res = http.request(req)
    case res
    when Net::HTTPSuccess, Net::HTTPRedirection
      return Nokogiri::XML.parse(res.body)
    else
      return nil
    end
  end
  
  def reset
    puts "=== Resetting launcher rotation..."
    turn_down(ResetTimes[:down])
    turn_left(ResetTimes[:left])
  end
  
  def fire_at_and_reset(right_time, up_time)
    puts "=== Aim..."
    turn_right(right_time)
    turn_up(up_time)
    puts "===== FIRE!!!"
    fire
    reset
  end
  
  def turn_left(time); rotate("L", time); end
  def turn_right(time); rotate("R", time); end
  def turn_up(time); rotate("U", time); end
  def turn_down(time); rotate("D", time); end
  
  def rotate(direction, time)
    while time > 0
      if time > MaxPerRotation
        iteration_time = MaxPerRotation
      else
        iteration_time = time
      end
      `USBMissileLauncherUtils -#{direction} -S #{iteration_time}`
      time -= MaxPerRotation
    end
  end
  
  def fire
    system("USBMissileLauncherUtils -F")
    sleep 2
  end

end

@bp = BuildPunisher.new

@bp.config["users"].each do |name, positions|
  if !ENV['user'] or ENV['user'] == name
    puts "===== #{name}"
    @bp.fire_at_and_reset(positions["right"], positions["up"])
  end
end
