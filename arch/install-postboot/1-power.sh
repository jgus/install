#!/bin/bash

# common/files/etc/skel/.config/powermanagementprofilesrc
((ALLOW_POWEROFF)) || cat << EOF >>/etc/polkit-1/rules.d/10-disable-shutdown.rules
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.login1.reboot" ||
        action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
        action.id == "org.freedesktop.login1.power-off" ||
        action.id == "org.freedesktop.login1.power-off-multiple-sessions")
    {
        if (subject.isInGroup("wheel")) {
            return polkit.Result.YES;
        } else {
            return polkit.Result.NO;
        }
    }
});
EOF
((ALLOW_SUSPEND)) || cat << EOF >>/etc/polkit-1/rules.d/10-disable-suspend.rules
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.login1.suspend" ||
        action.id == "org.freedesktop.login1.suspend-multiple-sessions")
    {
        return polkit.Result.NO;
    }
});
EOF
((ALLOW_SUSPEND_TO_DISK)) || cat << EOF >>/etc/polkit-1/rules.d/10-disable-suspend-to-disk.rules
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.login1.hibernate" ||
        action.id == "org.freedesktop.login1.hibernate-multiple-sessions")
    {
        return polkit.Result.NO;
    }
});
EOF
