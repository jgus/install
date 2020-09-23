#!/bin/bash

pip install wheel
[[ "${PIP_PACKAGES[@]}" == "" ]] || pip install "${PIP_PACKAGES[@]}"
