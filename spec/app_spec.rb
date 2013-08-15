APP_PATH = File.expand_path(File.dirname(__FILE__) + "/..")
$LOAD_PATH.unshift APP_PATH

require 'app'
require 'rspec'

describe R53Lookup::Utils do
  subject { described_class }

  before do
    Fog.mock!
    Fog::Mock.reset
    R53Lookup::Config.stub(:aws_access_key_id) { "id" }
    R53Lookup::Config.stub(:aws_secret_access_key){ "secret" }
    subject.api.zones.create(:domain => "example1.com.")
    subject.api.zones.create(:domain => "example2.com.")
  end

  it { should respond_to :parse_zone }
  describe :parse_zone do
    context 'with a valid suffix' do
      it "should return the  zone" do
        subject.parse_zone("test.example1.com").should == "example1.com."
      end

      it "returns the zone if the zone and name match" do
        subject.parse_zone("example1.com").should == "example1.com."
      end

      it "handles all valid zones" do
        subject.parse_zone("test.example2.com").should == "example2.com."
      end
    end

    context 'with an invalid suffix' do
      it "should return nil for the zone" do
        subject.parse_zone("test.foo.com").should == nil
      end
    end
  end

  it { should respond_to :lookup }
  describe :lookup do
    let(:zone) { subject.api.zones.all.select{|e| e.domain == "example1.com."} }

    before do
      zone.service.stub(:list_resource_record_sets){ |zone_id, options|
        list_response = double("list_response")
        list_response.stub(:body) do
          records = [
           {
             'Name' => "us-east-1-a.route.example1.com.",
             'Type' => "A",
             'TTL' => 0,
             'AliasTarget' => { 'HostedZoneId' => "", 'DNSName' => "123.us-east-1.elb.amazonaws.com."},
             'ResourceRecords' => []
           },
           {
             'Name' => "*.example1.com.",
             'Type' => "A",
             'TTL' => 0,
             'AliasTarget' => { 'HostedZoneId' => "", 'DNSName' => "example1.com."},
             'ResourceRecords' => []
           },
           {
             'Name' => "example1.com.",
             'Type' => "A",
             'TTL' => 0,
             'AliasTarget' => { 'HostedZoneId' => "", 'DNSName' => "us-east-1-a.route.example1.com."},
             'ResourceRecords' => []
           }
          ]

          {
            'ResourceRecordSets' => records.select{|r| r['Name'] == options[:name]}
          }
        end
        list_response
      }
    end

    it "should return the name" do
      subject.lookup("us-east-1-a.route.example1.com").should == "123.us-east-1.elb.amazonaws.com."
    end

    it "should recurse until an elb is found" do
      subject.lookup("test.example1.com").should == "123.us-east-1.elb.amazonaws.com."
    end

  end
end
