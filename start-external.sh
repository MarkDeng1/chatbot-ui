#!/bin/bash

echo "Starting MentalShield Project on all network interfaces..."
echo "External access: http://20.5.19.78:3000"
echo "Local access: http://localhost:3000"

# 使用npx直接运行next start，并指定hostname
npx next start --hostname 0.0.0.0 --port 3000
