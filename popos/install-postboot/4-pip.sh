#!/bin/bash

install python3-pip
pip install wheel
[[ "${PIP_PACKAGES[@]}" == "" ]] || pip install "${PIP_PACKAGES[@]}"
