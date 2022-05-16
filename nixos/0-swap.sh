#!/usr/bin/env -S bash -e

mkswap $1
swapon $1
