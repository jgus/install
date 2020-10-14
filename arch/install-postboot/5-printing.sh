#!/bin/bash
if ((HAS_GUI))
then
    install cups cups-pdf ghostscript gsfonts cnrdrvcups-lb-bin
    systemctl enable org.cups.cupsd.service
fi
