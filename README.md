The OneAPM CI Agent faithfully collects events and metrics and brings
them to [OneAPM](http://www.oneapm.com) on your behalf so that
you can do something useful with your monitoring and performance data.

## Setup your environment

Required:
- python 2.6 or 2.7
- bundler

```
# Create a virtual environment and install the dependencies:
bundle install
rake setup_env

# Activate the virtual environment
source venv/bin/activate

# Lint
bundle exec rake lint

# Run a flavored test
bundle exec rake ci:run[apache]
```

# How to configure the Agent

If you are using packages on linux, the main configuration file lives
in `/etc/oneapm-ci-agent/oneapm-ci-agent.conf`. Per-check configuration files are in
`/etc/oneapm-ci-agent/conf.d`. We provide an example in the same directory
that you can use as a template.
