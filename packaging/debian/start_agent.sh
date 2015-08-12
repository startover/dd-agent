#!/bin/sh

PATH=/opt/oneapm-ci-agent/embedded/bin:/opt/oneapm-ci-agent/bin:$PATH

exec /opt/oneapm-ci-agent/bin/supervisord -c /etc/oneapm-ci-agent/supervisor.conf --pidfile /var/run/oneapm-agent-supervisord.pid
