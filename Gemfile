source "https://rubygems.org"

version = (File.read(".ruby-version").chomp.split("-").first rescue nil)
ruby version || "2.0.0"

gem "sinatra"
gem "fog"
gem "puma"
gem "excon-middleware-aws-exponential_backoff"

group :development do
  gem "rspec"
end
