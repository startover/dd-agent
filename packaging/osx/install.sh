#!/bin/bash
# OneAPM Agent install script for Mac OS X.
set -e
logfile=oneapm-ci-agent-install.log
dmg_file=/tmp/oneapm-ci-agent.dmg
dmg_url="https://s3.amazonaws.com/oneapm-ci-agent/oneapm-ci-agent-5.4.2.dmg"

# Root user detection
if [ $(echo "$UID") = "0" ]; then
    sudo_cmd=''
else
    sudo_cmd='sudo'
fi

# get real user (in case of sudo)
real_user=`logname`
export TMPDIR=`sudo -u $real_user getconf DARWIN_USER_TEMP_DIR`
cmd_real_user="sudo -Eu $real_user"

# In order to install with the right user
rm -f /tmp/oneapm-ci-agent-install-user
echo $real_user > /tmp/oneapm-ci-agent-install-user

function on_error() {
    printf "\033[31m$ERROR_MESSAGE
It looks like you hit an issue when trying to install the Agent.

Troubleshooting and basic usage information for the Agent are available at:

    http://support.oneapm.com/

If you're still having problems, please contact to support@oneapm.com
and we'll do our very best to help you solve your problem.\n\033[0m\n"
}
trap on_error ERR

if [ -n "$CI_LICENSE_KEY" ]; then
    license_key=$CI_LICENSE_KEY
fi

if [ ! $license_key ]; then
    printf "\033[31mLicense key not available in CI_LICENSE_KEY environment variable.\033[0m\n"
    exit 1;
fi

# Install the agent
printf "\033[34m\n* Downloading and installing oneapm-ci-agent\n\033[0m"
rm -f $dmg_file
curl $dmg_url > $dmg_file
if [ "$sudo_cmd" = "sudo" ]; then
    printf "\033[34m\n  Your password is needed to install and configure the agent \n\033[0m"
fi
$sudo_cmd hdiutil detach "/Volumes/oneapm_ci_agent" >/dev/null 2>&1 || true
$sudo_cmd hdiutil attach "$dmg_file" -mountpoint "/Volumes/oneapm_ci_agent" >/dev/null
cd / && $sudo_cmd /usr/sbin/installer -pkg `find "/Volumes/oneapm_ci_agent" -name \*.pkg 2>/dev/null` -target / >/dev/null
$sudo_cmd hdiutil detach "/Volumes/oneapm_ci_agent" >/dev/null

# Set the configuration
if egrep 'license_key:( LICENSEKEY)?$' "/opt/oneapm-ci-agent/etc/oneapm-ci-agent.conf" > /dev/null 2>&1; then
    printf "\033[34m\n* Adding your API key to the Agent configuration: oneapm-ci-agent.conf\n\033[0m\n"
    $sudo_cmd sh -c "sed -i '' 's/license_key:.*/license_key: $license_key/' \"/opt/oneapm-ci-agent/etc/oneapm-ci-agent.conf\""
    $sudo_cmd chown $real_user:admin "/opt/oneapm-ci-agent/etc/oneapm-ci-agent.conf"
    printf "\033[34m* Restarting the Agent...\n\033[0m\n"
    $cmd_real_user "/opt/oneapm-ci-agent/bin/oneapm-ci-agent" restart >/dev/null
else
    printf "\033[34m\n* Keeping old oneapm-ci-agent.conf configuration file\n\033[0m\n"
fi

# Starting the app
$cmd_real_user open -a 'OneAPM Agent.app'

# Wait for metrics to be submitted by the forwarder
printf "\033[32m
Your Agent has started up for the first time. We're currently verifying that
data is being submitted. You should see your Agent show up in OneAPM shortly
at:

    https://tpm.oneapm.com\033[0m

Waiting for metrics..."

c=0
while [ "$c" -lt "30" ]; do
    sleep 1
    echo -n "."
    c=$(($c+1))
done

curl -f http://127.0.0.1:17123/status?threshold=0 > /dev/null 2>&1
success=$?
while [ "$success" -gt "0" ]; do
    sleep 1
    echo -n "."
    curl -f http://127.0.0.1:17123/status?threshold=0 > /dev/null 2>&1
    success=$?
done

# Metrics are submitted, echo some instructions and exit
printf "\033[32m

Your Agent is running and functioning properly. It will continue to run in the
background and submit metrics to OneAPM.

If you ever want to stop the Agent, please use the OneAPM Agent App or
oneapm-ci-agent command.

It will start automatically at login, if you want to enable it at startup,
run these commands: (the agent will still run as your user)

    sudo cp '/opt/oneapm-ci-agent/etc/com.oneapm.agent.plist' /Library/LaunchDaemons
    sudo launchctl load -w /Library/LaunchDaemons/com.oneapm.agent.plist

\033[0m"
