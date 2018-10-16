initScript="/etc/init.d/oneagent"
systemdServiceName="oneagent"

runServiceCommand() {
    local command=$1

    if [[ -f /bin/systemctl ]]; then
        if systemctl is-enabled --quiet $systemdServiceName; then
            systemctl $command $systemdServiceName
        else
            echo "ERROR: service ${systemdServiceName} not enabled/found!"
            return 1
        fi
    else
        if [[ -f "${initScript}" ]]; then
            "${initScript}" $command
        else
            echo "ERROR: ${initScript} not found!"
            return 1
        fi
    fi
}
