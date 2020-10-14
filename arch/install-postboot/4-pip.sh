#!/bin/bash

install python-pip
pip install wheel
[[ "${PIP_PACKAGES[@]}" == "" ]] || pip install "${PIP_PACKAGES[@]}"
