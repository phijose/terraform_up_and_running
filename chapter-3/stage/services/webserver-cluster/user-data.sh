#!/bin/bash

cat > index.html <<EOF
<h1>Hello, World</h1>
<p>DB address: ${db_address}</p>
<p>DB port: ${db_port}</p>
EOF

# Use Python's built-in server as a backup if busybox isn't there
nohup python3 -m http.server ${listening_port} &