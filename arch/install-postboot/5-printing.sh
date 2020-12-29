#!/bin/bash
if ((HAS_GUI))
then
    install cups cups-pdf ghostscript gsfonts cnrdrvcups-lb-bin
    systemctl enable cups
fi
