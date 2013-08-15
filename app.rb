require 'sinatra'
require 'fog'

module R53Lookup
  module Config
    extend self

    def aws_access_key_id
      env!("AWS_ACCESS_KEY_ID")
    end

    def aws_secret_access_key
      env!("AWS_SECRET_ACCESS_KEY")
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

    def lookup(name)
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
        match
      else
        lookup(match)
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
    get '/' do
      'Usage: curl /lookup?name=test.example1.com'
    end

    get '/lookup' do
      return [400, "name required"] unless name = params["name"]
      return [400, "#{name} must belong to valid zone: #{Utils.zone_names.join(', ')}"] unless Utils.valid_zone?(name)

      if result = Utils.lookup(name)
        result
      else
        halt 404
      end
    end
  end

end
