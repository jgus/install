#!/bin/bash
((HAS_OPTIMUS)) && systemctl enable optimus-manager.service || true
