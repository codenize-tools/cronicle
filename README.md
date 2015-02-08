# Cronicle

TODO: Write a gem description

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
on servers: :your_amazon_linux_hostname do
  job :my_job, user: 'ec2-user', schedule: "* * * * *" do
    puts "hello"
  end
end

$ cronicle exec my_job
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

## Contributing

1. Fork it ( https://github.com/[my-github-username]/cronicle/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
