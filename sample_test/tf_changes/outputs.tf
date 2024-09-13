##############################################################################
# Outputs
##############################################################################

output "istio_ingressgateway_hostname" {
  description = "Each control plane's default istio-ingressgateway load balancer hostname"
  value = {
    for k, v in data.kubernetes_service.istio_ingressgateway : k => v.status[0].load_balancer[0].ingress[0]
  }
}

output "all_istio_public_ingress_gateways_hostname" {
  description = "All istio ingress gateways load balancers hostname for each istio controlplane"
  value = {
    for k, v in data.kubernetes_service.all_istio_public_ingress_gateways : k => v.status[0].load_balancer[0].ingress[0]
  }
}

output "sdnlb_ips" {
  description = "The list of external IP addresses for the sDNLB load balancer of the first controlplane configuration, if having createSDNLB=true and at least one sDNLB svc created"
  value       = length(data.kubernetes_service.sdnlb_loadbalancer) > 0 ? tolist(data.kubernetes_service.sdnlb_loadbalancer[0].status[0].load_balancer[0].ingress[*].ip) : []
}

output "all_istio_sdnlbs_gateways_ips" {
  description = "All the sDNLB load balancers IPs for each istio controlplane"
  value = {
    for k, s in data.kubernetes_service.all_sdnlb_loadbalancers : k => s.status[0].load_balancer[0].ingress[*].ip
  }
}

output "ingress_subdomains" {
  description = "Each control plane's default istio-ingressgateway subdomain along with the secret name to enable TLS"
  value       = length(module.ingress_subdomain) > 0 ? module.ingress_subdomain : null
}
