#!/bin/bash

install python3-pip
pip3 install wheel
[[ "${PIP_PACKAGES[@]}" == "" ]] || pip3 install "${PIP_PACKAGES[@]}"
