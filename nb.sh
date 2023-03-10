#!/bin/bash

SCRATCH_DIR="/tmp/haproxy/scratch"

if [ ! -d "$SCRATCH_DIR" ]; then
	# Make the scratch directory and all the parents
	mkdir -p "$SCRATCH_DIR"
fi

# update the kubectl command below with the relavant kubeconfig and service name/namespace

# Obtain the IPv4 address of the ingress controller service
nbipv4=$( kubectl get svc --kubeconfig=kubeconfig -n {service namespace} {service name} -o jsonpath="{.status.loadBalancer.ingress[*].ip}" )
# Expect a single IPv4 address to be returned from the above command
if ! [[ "$nbipv4" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
	echo "Failed to get Nodebalancer IPv4 address command returned: $nbipv4"
	exit
fi

# Obtain the Nodebalancer ID tied to the IPv4 address
nbid=$( linode-cli nodebalancers list --json --ipv4 "$nbipv4" | jq -r '.[].id' )
if ! [[ "$nbid" =~ ^[0-9]+$ ]]; then
	echo "$nbipv4: Failed to get Nodebalancer ID command returned: $nbid"
	exit
fi

# Now get the configuration IDs for both port 80 and 443
configid80=$( linode-cli nodebalancers configs-list "$nbid" --json | jq '.[] | select(.'port' == 80) | .id' )
configid443=$( linode-cli nodebalancers configs-list "$nbid" --json | jq '.[] | select(.'port' == 443) | .id' )

if ! [[ "$configid80" =~ ^[0-9]+$ ]]; then
	echo "$nbipv4/$nbid: Failed to get Port 80 Config ID: $configid80"
	exit
fi

if ! [[ "$configid443" =~ ^[0-9]+$ ]]; then
	echo "$nbipv4/$nbip: Failed to get Port 443 Config ID: $configid443"
	exit
fi

# Obtain the IP and Port combinations tied to port 80
config80ipport=$(linode-cli nodebalancers nodes-list "$nbid" "$configid80" --json | jq  -r '.[].address')
if [ -z "$config80ipport" ]; then
	echo "$nbipv4/$nbip/$configid80: No target IP and Ports for port 80 configuration."
fi

# Obtain the IP and Port combinations tied to port 443
config443ipport=$(linode-cli nodebalancers nodes-list "$nbid" "$configid443" --json | jq  -r '.[].address')
if [ -z "$config443ipport" ]; then
	echo "$nbipv4/$nbip/$configid443: No target IP and Ports for port 443 configuration."
fi


# Generate the backend config for HTTP
cat > "$SCRATCH_DIR/newconfig80.txt" <<EOF

# Backend80 config auto-generated by nb.sh script
backend backend80
mode tcp
balance roundrobin
timeout check 3s
option tcp-check
default-server error-limit 2 inter 5s rise 2 fall 2

EOF

# Add the IP:PORT combinations
while read nbipport; do
	if ! [[ "$nbipport" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:[0-9]+$ ]]; then
		echo "$nbipv4/$nbip/$configid80: Malformed IPv4:Port combination, command returned: $nbipport"
		exit
	fi
	echo "server $nbipport $nbipport check error-limit 5 observe layer4 weight 100 check" >> "$SCRATCH_DIR/newconfig80.txt"
done < <( echo "$config80ipport" | sort )


# Backend80 config auto-generated by nb.sh script
cat > "$SCRATCH_DIR/newconfig443.txt" <<EOF

# Backend443 config auto-generated by nb.sh script
backend backend443
mode tcp
balance roundrobin
timeout check 3s
option tcp-check
default-server error-limit 2 inter 5s rise 2 fall 2

EOF

# Add the IP:PORT combinations
while read nbipport; do
	if ! [[ "$nbipport" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:[0-9]+$ ]]; then
		echo "$nbipv4/$nbip/$configid443: Malformed IPv4:Port combination, command returned: $nbipport"
		exit
	fi
	echo "server $nbipport $nbipport check error-limit 5 observe layer4 weight 100 check" >> "$SCRATCH_DIR/newconfig443.txt"
done < <( echo "$config443ipport" | sort )

# Now generate the new complete config
cat "/etc/haproxy/haproxy.base" "$SCRATCH_DIR/newconfig80.txt" "$SCRATCH_DIR/newconfig443.txt" > "$SCRATCH_DIR/new_haproxy.cfg"

# Check for changes
if cmp -s "/etc/haproxy/haproxy.cfg" "$SCRATCH_DIR/new_haproxy.cfg" ; then
	echo "nothing changed"
else
	echo "config updated but not committed"
	# this is commented out so that no changes are actually committed
	# copy the new one over the old one, then restart
#cp "$SCRATCH_DIR/new_haproxy.cfg" "/etc/haproxy/haproxy.cfg"
#systemctl restart haproxy
fi
