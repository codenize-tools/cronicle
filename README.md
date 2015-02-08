# Cronicle

It is a tool for execute script, and define cron on remote hosts.

[![Gem Version](https://badge.fury.io/rb/cronicle.svg)](http://badge.fury.io/rb/cronicle)
[![Build Status](https://travis-ci.org/winebarrel/cronicle.svg?branch=master)](https://travis-ci.org/winebarrel/cronicle)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'cronicle'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install cronicle

## Usage

```
Commands:
  cronicle apply           # Apply cron jobs to remote hosts
  cronicle exec JOB_NAME   # Execute a job on remote hosts
  cronicle help [COMMAND]  # Describe available commands or one specific command

Options:
  -f, [--file=FILE]                    # Job definition file
                                       # Default: Jobfile
  -h, [--hosts=HOSTS]                  # Hosts definition file
  -r, [--target-roles=one two three]   # Target host role list
  -p, [--sudo-password=SUDO-PASSWORD]  # Sudo password
      [--dry-run], [--no-dry-run]      # Do not actually change
  -c, [--ssh-config=SSH-CONFIG]        # OpenSSH configuration file
      [--connection-timeout=N]         # SSH connection timeout
      [--concurrency=N]                # SSH concurrency
                                       # Default: 10
      [--libexec=LIBEXEC]              # Cronicle libexec path
                                       # Default: /var/lib/cronicle/libexec
  -v, [--verbose], [--no-verbose]      # Verbose mode
      [--debug], [--no-debug]          # Debug mode
      [--color], [--no-color]          # Colorize log
                                       # Default: true
```

## Quick Start

```sh
$ cat Jobfile
on servers: :your_hostname do
  job :my_job, user: 'ec2-user', schedule: "* * * * *" do
    puts "hello"
  end
end

$ cronicle exec my_job
my_job on your_hostname/ec2-user> Execute job
my_job on your_hostname/ec2-user> hello

$ cronicle apply --dry-run
my_job on your_hostname/ec2-user> Create job: schedule="* * * * *" (dry-run)

$ cronicle apply
my_job on your_hostname/ec2-user> Create job: schedule="* * * * *"

$ ssh your_hostname 'crontab -l'
* * * * * /var/lib/cronicle/libexec/ec2-user/my_job 2>&1 | logger -t cronicle/ec2-user/my_job

$ ssh your_hostname 'cat /var/lib/cronicle/libexec/ec2-user/my_job'
#!/usr/bin/env ruby
puts "hello"
```

## Hosts definition file
```
server1,server2,...
```
```
server1
server2
...
```
```javascript
{
  "servers": {
    "server1": ["web", "app"]
    "server2": ["db"]
  }
}
```
```javascript
{
  "roles": {
    "web": ["server1"],
    "app": ["server1"],
    "db": ["server2"]
  }
}
```
