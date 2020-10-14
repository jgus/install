#!/bin/bash

install jdk-openjdk jdk11-openjdk jdk8-openjdk
((HAS_GUI)) && install icedtea-web
