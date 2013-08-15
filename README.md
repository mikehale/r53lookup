# Route53Lookup

Given a set of read-only IAM creds for your AWS account this service
will attempt to recursively find the ELB behind an ALIAS A record you specify.

## Usage

```bash
$ curl http://<my-app>.herokuapp.com/lookup?name=test.example1.com
123.us-east-1.elb.amazonaws.com
```

## Setup
```bash
$ heroku create
$ git push heroku master
$ heroku config:set AWS_ACCESS_KEY_ID=xxx AWS_SECRET_ACCESS_KEY=xxx
$ curl 'http://<my-app>.herokuapp.com/lookup?name=test.example1.com'
```

## Hacking
```bash
bundle install
bundle exec rspec spec
```
