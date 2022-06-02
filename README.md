# How to run steep-playground locally

```
bundle install
bundle exec rackup
```

and open http://localhost:9292.


# How to run steep-playground in production

Here is an example of systemd steep-playground.service file.

```
[Unit]
Description=steep-playground API server
After=network.target

[Service]
Type=simple
WorkingDirectory=/path/to/steep-playground
Environment=PATH=/path/to/ruby/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/path/to/ruby/bin/bundle exec puma -t 1:1 -w 16 -e production -p 1111
TimeoutSec=300
Restart=always

[Install]
WantedBy=default.target
```
