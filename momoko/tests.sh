#!/bin/bash

for i in {1..1000}; do
    ((s=${RANDOM}%10))
    curl -v "http://localhost:8888/sleep/${s}" &
done

