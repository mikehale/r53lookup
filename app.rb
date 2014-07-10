require 'sinatra'
require 'fog'

class Rack::LogRequestID
  def initialize(app); @app = app; end

  def call(env)
    puts "at=start request_id=#{env['HTTP_HEROKU_REQUEST_ID']}"
    result = @app.call(env)
    puts "at=finish request_id=#{env['HTTP_HEROKU_REQUEST_ID']}"
    result
  end
end

module R53Lookup
  module Config
    extend self

    def aws_access_key_id
      env!("AWS_ACCESS_KEY_ID")
    end

    def aws_secret_access_key
      env!("AWS_SECRET_ACCESS_KEY")
    end

    def port
      env!("PORT")
    end

    private
    def env!(key)
      unless value = ENV[key]
        raise "#{key} must be set"
      end
      value
    end
  end

  module Utils
    extend self

    def api
      @api ||= Fog::DNS::AWS.new(:aws_access_key_id => Config.aws_access_key_id, :aws_secret_access_key => Config.aws_secret_access_key)
    end

    def parse_zone(name)
      name = "#{name}." unless name =~ /\.\Z/
      zone_names.detect{|zone| name =~ /#{Regexp.escape(zone)}\Z/}
    end

    def lookup(name, alias_chain=[])
      zone_name = parse_zone(name)
      zone = zones.detect{|z|z.domain == zone_name}
      return nil unless zone

      match = if record = zone.records.get(name, 'A')
                record.alias_target["DNSName"]
              else
                # no record found so assume wildcard match
                record = zone.records.get('*.' + zone_name, 'A')
                record.alias_target["DNSName"] if record
              end
      return nil unless match

      if match =~ /#{Regexp.escape('.elb.amazonaws.com.')}/
        alias_chain << match
      else
        lookup(match, alias_chain << match)
      end
    end

    def valid_zone?(name)
      zone_names.any? do |zone|
        /#{Regexp.escape(zone[0..-2])}\Z/ =~ name
      end
    end

    def zones
      @zones ||= api.zones.all
    end

    def zone_names
      zones.map(&:domain)
    end
  end

  class Web < Sinatra::Base
    use Rack::LogRequestID
    
    get '/' do
      'Usage: curl /lookup?name=test.example1.com'
    end

    get '/lookup' do
      return [400, "name required"] unless name = params["name"]
      return [400, "#{name} must belong to valid zone: #{Utils.zone_names.join(', ')}"] unless Utils.valid_zone?(name)

      if result = Utils.lookup(name)
        result.join("\n")
      else
        halt 404
      end
    end

    def self.start
      Rack::Server.start(:app => Web.new, :environment => :none, :server => :puma, :Port => Config.port)
    end
  end

end
