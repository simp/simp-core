#!/bin/bash

# Clean up yum cache
yum clean all
rm -rf /var/cache/yum

# Clean up docs that ignore the yum settings

docdirs=$(rpm --eval '%{__docdir_path}' | sed 's/:\+/ /g')

for dir in $docdirs; do
  if [ -d "${dir}" ]; then
    find "${dir}" -type f -delete
  fi
done
