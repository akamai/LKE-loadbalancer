# LKE-loadbalancer
Load Balancer for Linode  Kubernetes Engine

## Known Issues/Limits

* The current scraping configuration uses kubectl to obtain the external IP address of the nginx controller for the target cluster. It then uses that address to obtain the NodeBalancer ID and Config ID via linode-cli, which then allows it to poll linode-cli for changes to the node pool. 

* The IP sharing failover is configured per this guide - https://www.linode.com/docs/guides/ip-failover/#configure-failover - BGP failover can converge in a longer time vs. failover that combines BGP with a higher fidelity failover/heartbeat sharing. Implementing keepalived as described here - https://www.linode.com/docs/guides/keepalived-with-bgp-failover/ will improve failover recovery time. 

## To-dos 

* Remove the linode-cli calls from the script, and pull the backend node information directly via kubectl.

## Diagram 
![peloton- alt load balancer config -2](https://user-images.githubusercontent.com/19197357/207985916-7cb03032-e7cd-419f-800e-4c1ef2870ea6.png)

## Setup Script

## Insfrastructure Provisioning 

1. Use the supplied TF files as a template to create 2 Linodes in the desired region. 

## Basic host bootstrapping and hardening 

1. Login as root, and run the bootstrap.sh script as root to install the needed tools and enable ubuntu auto-updates.

2. Create a sudo user for ssh login purposes (as we will disable root SSH login in the next step). 

3. Harden the SSH configuration- within sshd_config, disable root login, and restart sshd.
```
sed -i -e  's/PermitRootLogin yes/PermitRootLogin no/g'  /etc/ssh/sshd_config
systemctl restart sshd
```
4. Copy the haproxy.base and nb.sh files to /etc/haproxy. Set nb.sh to execute permission - ```chmod +x /etc/haproxy/nb.sh```

5. Copy the kubeconfig from the cluster that will sit behind the load balancer into /etc/haproxy (be sure to keep it's name 'kubeconfig').

6. Generate a linode API token, with a scope limited to only read-only of NodeBalancer objects. Run ```linode-cli configure``` and input this token when asked. 

7. Update the first line of nb.sh, so that the correct namespace and service from the cluster is specified. For example, this is the nb.sh line 1 from the lb-stg-ewr-1 load balancer - 

```
kubectl get svc --kubeconfig=/etc/haproxy/kubeconfig -n {namespace of sevice} {service} -o jsonpath="{.status.loadBalancer.ingress[*].ip}" > /etc/haproxy/nbip.txt
```

8. Run nb.sh for the first time, and verify that it's able to read via kubectl and the linode-cli, and generate a valid haproxy config, and that haproxy is running.

9. modify crontab to run the nb.sh script every minute, while surpressing stdout -

```
(crontab -l 2>/dev/null; echo "* * * * * /etc/haproxy/nb.sh >/dev/null 2>&1") | crontab -
```
10. Refer to Linode documentation for instructions on configuring Failover and Shared IP here - https://www.linode.com/docs/products/compute/compute-instances/guides/failover/. 
