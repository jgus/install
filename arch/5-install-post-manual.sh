#!/bin/bash
set -e

HOSTNAME=$(hostname)
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env
